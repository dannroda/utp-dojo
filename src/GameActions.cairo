use crate::models::Vec3;

#[starknet::interface]
pub trait IGameActions<T> {
    fn spawn_spaceship(ref self: T, spaceship_id: u128, spawn_pos: Vec3);
    fn despawn_spaceship(ref self: T, spaceship_id: u128);
    fn board_spaceship(ref self: T, spaceship_id: u128);
    fn unboard_spaceship(ref self: T, spaceship_id: u128, pos: Vec3);
    fn move_spaceship(ref self: T, spaceship_id: u128, position: Vec3, direction: Vec3, p_speed: u64);
    fn ship_switch_reference_body(ref self: T, spaceship_id: u128, reference_body: u128, position: Vec3, direction: Vec3, speed: u64);
    fn player_move(ref self: T, dst: Vec3);
    fn collect_item(ref self: T, player_id: u128, collectable_type: u16, collectable_index: u8);
}


#[dojo::contract]
pub mod GameActions {

    use super::{IGameActions};
    use crate::models::{Player, Spaceship, Planet, CollectableTracker, PlayerPosition, ShipPosition, Vec3, InventoryItem};
    use crate::world::{current_pos, vec3_fp40_dist_sq, vec3_fp40_len_sq, vec3_sub, vec3_fp40_len, vec3_fp40_div_scalar, FP_UNIT, FP_UNIT_BITS};
    // We'll implement our own bitwise operations
    use array::ArrayTrait;
    use core::byte_array::ByteArray;
    use starknet::get_block_timestamp;
    use starknet::{ContractAddress, get_caller_address};

    use dojo::model::{ModelStorage};
    use dojo::event::EventStorage;
    use core::traits::BitAnd;
    use core::num::traits::Pow;

    const DEFAULT_REFERENCE_BODY_ID: u128 = 0;
    const MAX_SPAWN: u8 = 128;
    const FP_LEN_SQ_EPSION: i128 = 0x40000000; // 2^30

    const AREA_SIZE: i128 = 32;
    const PLAYER_WALKING_SPEED: i128 = 1 * FP_UNIT;
    const MAX_PLAYER_WALK_EPSILON2: i128 = 5 * FP_UNIT;
    const MAX_SPAWN_DISTANCE_SQUARED: i128 = 25 * FP_UNIT; // 5 meters
    const MAX_ITEM_PICKUP_D2: i128 = 64 * FP_UNIT; // 8 meters

    const SHIP_SPEED: i128 = 100 * FP_UNIT;
    const SHIP_HYPER_SPEED: i128 = 1000 * FP_UNIT;

    #[abi(embed_v0)]
    impl GameActionsImpl of IGameActions<ContractState> {

        fn spawn_spaceship(ref self: ContractState, spaceship_id: u128, spawn_pos: Vec3) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player : Player = world.read_model(player_id);
            let mut ship : Spaceship = world.read_model(spaceship_id);

            assert(ship.owner == player_id, 'NotOwner');
            assert((ship.status_flags & 1) == 0, 'AlreadySpawned');

            let player_pos_model : PlayerPosition = world.read_model(player_id);
            let player_pos = player_pos_model.pos;
            
            let distance_squared = vec3_fp40_dist_sq(spawn_pos, player_pos);
            assert(distance_squared <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

            ship.status_flags += 1;
            if ((ship.status_flags & 2) == 0) {
                ship.status_flags += 2;
            };
            ship.reference_body = player.reference_body;
            world.write_model(@ship);

            let mut ship_motion : ShipPosition = world.read_model(spaceship_id);
            ship_motion.pos = spawn_pos;
            ship_motion.speed = 0;
            ship_motion.dir = player_pos_model.dir;
            ship_motion.last_motion = get_block_timestamp().into();
            world.write_model(@ship_motion);
        }

        fn despawn_spaceship(ref self: ContractState, spaceship_id: u128) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model(spaceship_id);
            assert(ship.owner == player_id, 'NotOwner');
            assert((ship.status_flags & 1) != 0, 'AlreadySpawned');
            assert((ship.status_flags & 4) == 0, 'ShipNotEmpty');

            // Remove ship position model
            //world.delete_model::<ShipPosition>(spaceship_id);
            ship.status_flags -= 1;
            world.write_model(@ship);
        }

        fn board_spaceship(ref self: ContractState, spaceship_id: u128) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model((spaceship_id, player_id));
            
            assert((ship.status_flags & 1) != 0, 'ShipNotSpawned');
            assert((ship.status_flags & 2) != 0, 'ShipNotLanded');
            assert((ship.status_flags & 4) == 0, 'ShipAlreadyOccupied');

            let mut player : Player = world.read_model(player_id);
            assert((player.status_flags & 1) != 0, 'PlayerNotWalking');
            assert((player.status_flags & 2) == 0, 'PlayerAlreadyOnSpaceship');

            // check ship position agains player position
            let ship_pos : ShipPosition = world.read_model(spaceship_id);
            let mut player_pos_model : PlayerPosition = world.read_model(player_id);
            let mut player_pos = player_pos_model.pos;
            if (player_pos_model.speed > 0) {

                let speed : u128 = (player_pos_model.speed.into() * PLAYER_WALKING_SPEED).try_into().unwrap();
                player_pos = current_pos(player_pos_model.pos, player_pos_model.dir, player_pos_model.last_motion, speed);
            };

            let dist2 = vec3_fp40_dist_sq(player_pos, ship_pos.pos);
            assert(dist2 <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

            ship.status_flags += 4;
            world.write_model(@ship);

            player.status_flags += 1;
            world.write_model(@player);
        }

        fn unboard_spaceship(ref self: ContractState, spaceship_id: u128, pos: Vec3) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model((spaceship_id, player_id));
            assert((ship.status_flags & 2) != 0, 'ShipNotLanded');
            assert((ship.status_flags & 4) != 0, 'ShipNotOccupied');
            // Get ship position to check last motion time
            let mut ship_pos : ShipPosition = world.read_model(spaceship_id);
            assert(ship_pos.speed > 0, 'ShipMoving');
            let dist2 = vec3_fp40_dist_sq(ship_pos.pos, pos);
            assert(dist2 <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

            let mut player : Player = world.read_model(player_id);
            assert((player.status_flags & 1) == 0, 'PlayerWalking');
            assert((player.status_flags & 2) != 0, 'PlayerNotOnSpaceship');

            let mut player_pos : PlayerPosition = world.read_model(player_id);
            player_pos.pos = pos;
            player_pos.speed = 0;
            world.write_model(@player_pos);

            ship.status_flags -= 4;
            world.write_model(@ship);

            player.status_flags -= 1;
            world.write_model(@player);
        }

        fn move_spaceship(ref self: ContractState, spaceship_id: u128, position: Vec3, direction: Vec3, p_speed: u64) {
            assert(p_speed.into() <= FP_UNIT, 'Speed too large (under 1)');
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model((spaceship_id, player_id));

            assert((ship.status_flags & 1) != 0, 'Ship not spawned');
            assert((ship.status_flags & 4) != 0, 'Ship not being driven by player');
            
            // Check that the direction vector is normalized
            // Using fixed point arithmetic with a small epsilon for floating point comparison
            let len2 = vec3_fp40_len_sq(direction);
            assert(len2 >= FP_UNIT - FP_LEN_SQ_EPSION && len2 <= FP_UNIT + FP_LEN_SQ_EPSION, 'Direction not normalized');
            
            // Get current position from model
            let mut ship_pos_model : ShipPosition = world.read_model(spaceship_id);
            if (ship_pos_model.speed > 0) {

                let mut speed_mode : u64 = SHIP_SPEED.try_into().unwrap();
                if ((ship.status_flags & 8) != 0) {
                    speed_mode = SHIP_HYPER_SPEED.try_into().unwrap();
                };
                let speed = ship_pos_model.speed * speed_mode;
                let model_pos = current_pos(ship_pos_model.pos, ship_pos_model.dir, ship_pos_model.last_motion, speed.into());
                // Check that the provided position doesn't differ too much from the current position
                let ship_dist2 = vec3_fp40_dist_sq(position, model_pos);
                let max_distance_squared: i128 = 1000 * FP_UNIT; // Maximum allowed squared distance
                assert(ship_dist2 <= max_distance_squared, 'Position change too large');
            };
            
            // Update ship position model
            let new_ship_pos = ShipPosition {
                ship: spaceship_id,
                pos: position,
                dir: direction,
                last_motion: get_block_timestamp().into(),
                speed: p_speed,
            };
            world.write_model(@new_ship_pos);
        }

        fn ship_switch_reference_body(ref self: ContractState, spaceship_id: u128, reference_body: u128, position: Vec3, direction: Vec3, speed: u64) {

            let mut world = self.world_default();
            let player_id = get_caller_address();

            let mut ship : Spaceship = world.read_model((spaceship_id, player_id));

            assert((ship.status_flags & 1) != 0, 'Ship not spawned');
            assert((ship.status_flags & 4) != 0, 'Ship not being driven by player');

            // Check that the direction vector is normalized
            // Using fixed point arithmetic with a small epsilon for floating point comparison
            let len2 = vec3_fp40_len_sq(direction);
            assert(len2 >= FP_UNIT - FP_LEN_SQ_EPSION && len2 <= FP_UNIT + FP_LEN_SQ_EPSION, 'Direction not normalized');

            ship.reference_body = reference_body;
            world.write_model(@ship);

            let mut ship_pos : ShipPosition = world.read_model(spaceship_id);
            ship_pos.pos = position;
            ship_pos.speed = speed;
            ship_pos.dir = direction;

            world.write_model(@ship_pos);
        }

        fn player_move(ref self: ContractState, dst: Vec3) {

            let mut world = self.world_default();
            let player_id = get_caller_address();

            let player : Player = world.read_model(player_id);
            assert((player.status_flags & 1) != 0, 'Player is not walking');

            // Get current position from model
            let player_pos_model : PlayerPosition = world.read_model(player_id);
            let model_pos = current_pos(player_pos_model.pos, player_pos_model.dir, player_pos_model.last_motion, PLAYER_WALKING_SPEED.try_into().unwrap());

            // calculate new dir
            let dif : Vec3 = vec3_sub(dst, model_pos);
            let len = vec3_fp40_len(dif);
            let dir = vec3_fp40_div_scalar(dif, len);

            // Update player position model
            let new_player_pos = PlayerPosition {
                player: player_id,
                pos: model_pos,
                dir: dir,
                dest: dst,
                last_motion: get_block_timestamp().into(),
                speed: 0,
            };
            world.write_model(@new_player_pos);
        }

        fn collect_item(ref self: ContractState, player_id: u128, collectable_type: u16, collectable_index: u8) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player : Player = world.read_model(player_id);
            let planet : Planet = world.read_model(player.reference_body);
            let player_pos_model : PlayerPosition = world.read_model(player_id);
            let player_pos = player_pos_model.pos;

            let area_x = player_pos.x / (AREA_SIZE * FP_UNIT).into();
            let area_y = player_pos.y / (AREA_SIZE * FP_UNIT).into();
            let area_z = player_pos.z / (AREA_SIZE * FP_UNIT).into();
            let area_hash = area_x * 31 * 31 + area_y * 31 + area_z;

            // Create a ByteArray from a string literal and then append values
            let mut count_seed = ByteArray { data: array![], pending_word: 0, pending_word_len: 0 };
            // Convert values to bytes before appending
            count_seed.append_byte(planet.seed.try_into().unwrap());
            count_seed.append_byte(planet.epoc.try_into().unwrap());
            count_seed.append_byte(area_hash.try_into().unwrap());
            count_seed.append_byte(collectable_type.try_into().unwrap());
            //let count_seed = planet.seed + planet.epoc + area_hash + collectable_type.into();
            let count_hash = core::sha256::compute_sha256_byte_array(@count_seed);
            let total_spawned = *count_hash.span().at(7) % MAX_SPAWN.into();

            assert(collectable_index.into() < total_spawned, 'InvalidIndex');

            // Create a new ByteArray for position seed by copying the count_seed and adding the collectable_index
            let mut pos_seed = ByteArray { data: count_seed.data.clone(), pending_word: 0, pending_word_len: 0 };
            pos_seed.append_byte(collectable_index.into());
            let item_hash = core::sha256::compute_sha256_byte_array(@pos_seed);

            let span = item_hash.span(); // span of 32 bit elements
            // Convert u32 to i128 using try_into().unwrap()
            let span_0_i128: i128 = (*span.at(0)).try_into().unwrap();
            let span_1_i128: i128 = (*span.at(1)).try_into().unwrap();
            let span_2_i128: i128 = (*span.at(2)).try_into().unwrap();
            
            let offset_x = (span_0_i128 * FP_UNIT / 0xFFFFFFFF_i128) * AREA_SIZE;
            let offset_y = (span_1_i128 * FP_UNIT / 0xFFFFFFFF_i128) * AREA_SIZE;
            let offset_z = (span_2_i128 * FP_UNIT / 0xFFFFFFFF_i128) * AREA_SIZE;

            let item_pos = Vec3 {
                x: area_x * FP_UNIT + offset_x,
                y: area_y * FP_UNIT + offset_y,
                z: area_z * FP_UNIT + offset_z,
            };

            let d2 = vec3_fp40_dist_sq(item_pos, player_pos);
            assert(d2 <= MAX_ITEM_PICKUP_D2, 'TooFar');

            let area_key: i128 = area_hash * 1000_i128 + collectable_type.into();
            
            // Get existing tracker or create a new one
            let mut tracker : CollectableTracker = world.read_model(area_key);
            // TODO: detect if key not found
            //if (!tracker.is_some()) {
            //   tracker = CollectableTracker {
            //        id: area_key,
            //        area: area_hash.into(),
            //        collectable_type,
            //        bitfield: 0,
            //        epoc: 0,
            //    };
            //};
            
            let bitfield : u128 = if tracker.epoc == planet.epoc { tracker.bitfield } else { 0 };
            let mut bit_mask : u128 = 2_u128.pow(collectable_index.into());

            let is_already_collected = (bitfield & bit_mask) != 0;
            assert(!is_already_collected, 'AlreadyCollected');

            // Bitwise OR implementation
            tracker.bitfield = bitfield | bit_mask;
            tracker.epoc = planet.epoc;
            world.write_model(@tracker);


            // move to funtcion add_to_inventory
            {
                // Get the current inventory item or create a new one with count 0
                let current_item : InventoryItem = world.read_model((player_id, collectable_type));
                
                // TODO: detect empty result
                // {
                //    Option::Some(item) => item,
                //    None => InventoryItem { player_id: player_id, item_type: collectable_type, count: 0 },
                //};
                
                // Increment the count
                let new_item = InventoryItem { 
                    player_id: player_id, 
                    item_type: collectable_type, 
                    count: current_item.count + 1, 
                };
                
                // Save the updated inventory item
                world.write_model(@new_item);
            };
            
        }

    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        /// Use the default namespace "dojo_starter". This function is handy since the ByteArray
        /// can't be const.
        fn world_default(self: @ContractState) -> dojo::world::WorldStorage {
            self.world(@"utp_dojo")
        }
    }

}

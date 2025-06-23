use crate::models::Vec3;

#[starknet::interface]
pub trait IGameActions<T> {
    fn spawn_spaceship(ref self: T, spaceship_id: u128, spawn_pos: Vec3);
    fn despawn_spaceship(ref self: T, spaceship_id: u128);
    fn board_spaceship(ref self: T, spaceship_id: u128, player_id: u128);
    fn unboard_spaceship(ref self: T, spaceship_id: u128, player_id: u128);
    fn move_spaceship(ref self: T, spaceship_id: u128, position: Vec3, direction: Vec3);
    fn move_player(ref self: T, position: Vec3, direction: Vec3);
    fn collect_item(ref self: T, player_id: u128, collectable_type: u16, collectable_index: u8);
}


#[dojo::contract]
pub mod GameActions {

    use super::{IGameActions};
    use crate::models::{Player, Spaceship, Planet, CollectableTracker, PlayerPosition, ShipPosition, Vec3, InventoryItem};
    use crate::world::{current_pos};
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
    const MAX_SPAWN_DISTANCE_SQUARED: i128 = 10000;
    const AREA_SIZE: i128 = 1000;
    const MAX_SPAWN: u8 = 128;
    const FP_UNIT: i128 = 0x10000000000; // 2^40

    #[abi(embed_v0)]
    impl GameActionsImpl of IGameActions<ContractState> {

        fn spawn_spaceship(ref self: ContractState, spaceship_id: u128, spawn_pos: Vec3) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let player : Player = world.read_model(player_id);
            let mut ship : Spaceship = world.read_model(spaceship_id);

            assert(ship.owner == player_id, 'NotOwner');
            assert(!ship.is_spawned, 'AlreadySpawned');

            let player_pos_model : PlayerPosition = world.read_model(player_id);
            let player_pos = player_pos_model.pos;
            
            let dx = spawn_pos.x - player_pos.x;
            let dy = spawn_pos.y - player_pos.y;
            let dz = spawn_pos.z - player_pos.z;
            let distance_squared = dx * dx + dy * dy + dz * dz;
            assert(distance_squared <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

            // Create ship position model with the spawn position and player's direction
            let ship_pos_model = ShipPosition {
                ship: spaceship_id,
                pos: spawn_pos,
                dir: player_pos_model.dir,
                last_motion: get_block_timestamp().into(),
            };
            
            // Set ship position
            world.write_model(@ship_pos_model);

            ship.reference_body = player.reference_body;
            ship.is_spawned = true;
            world.write_model(@ship);
        }

        fn despawn_spaceship(ref self: ContractState, spaceship_id: u128) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            let mut ship : Spaceship = world.read_model(spaceship_id);
            assert(ship.owner == player_id, 'NotOwner');
            assert(ship.is_spawned, 'NotSpawned');
            assert(ship.passengers.len() == 0, 'ShipNotEmpty');

            // Remove ship position model
            //world.delete_model::<ShipPosition>(spaceship_id);
            ship.is_spawned = false;
            world.write_model(@ship);
        }

        fn board_spaceship(ref self: ContractState, spaceship_id: u128, player_id: u128) {
            let mut world = self.world_default();
            let mut ship : Spaceship = world.read_model(spaceship_id);
            assert(ship.passengers.len() < ship.capacity, 'Full');
            // Get ship position to check last motion time
            let mut ship_pos : ShipPosition = world.read_model(spaceship_id);
            let current_time: u128 = get_block_timestamp().into();
            assert(ship_pos.last_motion == current_time, 'ShipMoving');

            ship.passengers.append(player_id);
            world.write_model(@ship);
        }

        fn unboard_spaceship(ref self: ContractState, spaceship_id: u128, player_id: u128) {
            let mut world = self.world_default();
            let mut ship : Spaceship = world.read_model(spaceship_id);
            // Get ship position to check last motion time
            let mut ship_pos : ShipPosition = world.read_model(spaceship_id);
            let current_time: u128 = get_block_timestamp().into();
            assert(ship_pos.last_motion == current_time, 'ShipMoving');

            // Find the index of player_id in the passengers array
            let mut index = 0;
            let mut found = false;
            loop {
                if index >= ship.passengers.len() {
                    break;
                }
                if *ship.passengers.at(index) == player_id {
                    found = true;
                    break;
                }
                index += 1;
            };
            
            assert(found, 'PlayerNotOnboard');
            // Remove the passenger at the found index
            if found {
                let mut new_passengers = ArrayTrait::new();
                let mut i = 0;
                loop {
                    if i >= ship.passengers.len() {
                        break;
                    }
                    if i != index {
                        new_passengers.append(*ship.passengers.at(i));
                    }
                    i += 1;
                };
                ship.passengers = new_passengers;
            };
            world.write_model(@ship);
        }

        fn move_spaceship(ref self: ContractState, spaceship_id: u128, position: Vec3, direction: Vec3) {
            let mut world = self.world_default();
            let mut ship : Spaceship = world.read_model(spaceship_id);
            
            // Check that the direction vector is normalized
            // Using fixed point arithmetic with a small epsilon for floating point comparison
            let magnitude_squared = direction.x * direction.x + direction.y * direction.y + direction.z * direction.z;
            let epsilon: i128 = 10; // Small epsilon for fixed point comparison
            assert(magnitude_squared >= 1000000 - epsilon && magnitude_squared <= 1000000 + epsilon, 'Direction not normalized');
            
            // Get current position from model
            let mut ship_pos_model : ShipPosition = world.read_model(spaceship_id);
            let model_pos = ship_pos_model.pos;
            
            // Check that the provided position doesn't differ too much from the current position
            let dx = position.x - model_pos.x;
            let dy = position.y - model_pos.y;
            let dz = position.z - model_pos.z;
            let distance_squared = dx * dx + dy * dy + dz * dz;
            let max_distance_squared: i128 = 10000; // Maximum allowed squared distance
            assert(distance_squared <= max_distance_squared, 'Position change too large');
            
            // Calculate new position using current_pos function
            let new_pos = current_pos(position, direction, ship_pos_model.last_motion, 10); // Speed of 10 units
            
            // Update ship position model
            let new_ship_pos = ShipPosition {
                ship: spaceship_id,
                pos: new_pos,
                dir: direction,
                last_motion: get_block_timestamp().into(),
            };
            world.write_model(@new_ship_pos);

            if ship.reference_body != DEFAULT_REFERENCE_BODY_ID {
                let d2 = new_pos.x * new_pos.x + new_pos.y * new_pos.y + new_pos.z * new_pos.z;
                let planet : Planet = world.read_model(ship.reference_body);
                let max_radius_squared_i128: i128 = planet.max_radius_squared.try_into().unwrap();
                if d2 > max_radius_squared_i128 {
                    // Get planet position
                    let planet_pos_model : ShipPosition = world.read_model(ship.reference_body);
                    let planet_pos_vec = planet_pos_model.pos;
                    
                    // Create a new position by adding the planet position to the ship's position
                    let absolute_pos = Vec3 {
                        x: planet_pos_vec.x + new_pos.x,
                        y: planet_pos_vec.y + new_pos.y,
                        z: planet_pos_vec.z + new_pos.z,
                    };
                    
                    // Update the ship position model with the absolute position
                    let absolute_ship_pos = ShipPosition {
                        ship: spaceship_id,
                        pos: absolute_pos,
                        dir: direction,
                        last_motion: get_block_timestamp().into(),
                    };
                    world.write_model(@absolute_ship_pos);
                    ship.reference_body = DEFAULT_REFERENCE_BODY_ID;
                }
            } else {

                // here assign a new reference body when coming from default reference body
            }

            world.write_model(@ship);
        }

        fn move_player(ref self: ContractState, position: Vec3, direction: Vec3) {
            let mut world = self.world_default();
            let player_id = get_caller_address();
            
            // Check that the direction vector is normalized
            // Using fixed point arithmetic with a small epsilon for floating point comparison
            let magnitude_squared = direction.x * direction.x + direction.y * direction.y + direction.z * direction.z;
            let epsilon: i128 = 10; // Small epsilon for fixed point comparison
            assert(magnitude_squared >= 1000000 - epsilon && magnitude_squared <= 1000000 + epsilon, 'Direction not normalized');
            
            // Get current position from model
            let player_pos_model : PlayerPosition = world.read_model(player_id);
            let model_pos = current_pos(player_pos_model.pos, direction, player_pos_model.last_motion, 5); // Speed of 5 units for player
            
            // Check that the provided position doesn't differ too much from the current position
            let dx = position.x - model_pos.x;
            let dy = position.y - model_pos.y;
            let dz = position.z - model_pos.z;
            let distance_squared = dx * dx + dy * dy + dz * dz;
            let max_distance_squared: i128 = 5000; // Maximum allowed squared distance
            assert(distance_squared <= max_distance_squared, 'Position change too large');
            
            // Update player position model
            let new_player_pos = PlayerPosition {
                player: player_id,
                pos: position,
                dir: direction,
                last_motion: get_block_timestamp().into(),
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

            let span = item_hash.span();
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

            let dx = item_pos.x - player_pos.x;
            let dy = item_pos.y - player_pos.y;
            let dz = item_pos.z - player_pos.z;
            let distance_squared = dx * dx + dy * dy + dz * dz;
            assert(distance_squared <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

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
            
            let bitfield = if tracker.epoc == planet.epoc { tracker.bitfield } else { 0 };
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

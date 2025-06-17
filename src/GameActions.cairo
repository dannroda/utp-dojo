use super::IGameActions;
use super::models::{Player, Spaceship, Planet};
use super::components::{Position, Direction};

const DEFAULT_REFERENCE_BODY_ID: u128 = 0;

#[abi(embed_v0)]
impl GameActions of IGameActions<ContractState> {

    fn spawn_spaceship(self: @ContractState, spaceship_id: u128, player_id: u128, spawn_pos: Position) {
        let player = world::get_model::<Player>(player_id);
        let mut ship = world::get_model::<Spaceship>(spaceship_id);

        assert(ship.owner == player_id, 'NotOwner');
        assert(!ship.is_spawned, 'AlreadySpawned');

        let player_pos = world::get_component::<Position>(player_id);
        let dx = spawn_pos.x - player_pos.x;
        let dy = spawn_pos.y - player_pos.y;
        let dz = spawn_pos.z - player_pos.z;
        let distance_squared = dx * dx + dy * dy + dz * dz;
        assert(distance_squared <= MAX_SPAWN_DISTANCE_SQUARED, 'TooFar');

        let dir = world::get_component::<Direction>(player_id);

        world::set_component::<Position>(spaceship_id, spawn_pos);
        world::set_component::<Direction>(spaceship_id, dir);

        ship.reference_body = player.reference_body;
        ship.is_spawned = true;
        world::set_model::<Spaceship>(spaceship_id, ship);
    }

    fn despawn_spaceship(self: @ContractState, spaceship_id: u128, player_id: u128) {
        let mut ship = world::get_model::<Spaceship>(spaceship_id);
        assert(ship.owner == player_id, 'NotOwner');
        assert(ship.is_spawned, 'NotSpawned');
        assert(ship.passengers.len() == 0, 'ShipNotEmpty');

        world::remove_component::<Position>(spaceship_id);
        world::remove_component::<Direction>(spaceship_id);
        ship.is_spawned = false;
        world::set_model::<Spaceship>(spaceship_id, ship);
    }

    fn board_spaceship(self: @ContractState, spaceship_id: u128, player_id: u128) {
        let mut ship = world::get_model::<Spaceship>(spaceship_id);
        assert(ship.passengers.len() < ship.capacity, 'Full');
        assert(ship.last_moved_at == get_block_timestamp(), 'ShipMoving');

        ship.passengers.push(player_id);
        world::set_model::<Spaceship>(spaceship_id, ship);
    }

    fn unboard_spaceship(self: @ContractState, spaceship_id: u128, player_id: u128) {
        let mut ship = world::get_model::<Spaceship>(spaceship_id);
        assert(ship.last_moved_at == get_block_timestamp(), 'ShipMoving');

        ship.passengers = ship.passengers.remove(player_id);
        world::set_model::<Spaceship>(spaceship_id, ship);
    }

    fn move_spaceship(self: @ContractState, spaceship_id: u128, direction: Direction) {
        let mut ship = world::get_model::<Spaceship>(spaceship_id);
        let mut pos = world::get_component::<Position>(spaceship_id);

        pos.x += direction.yaw;
        pos.y += direction.pitch;
        pos.z += direction.roll;

        world::set_component::<Position>(spaceship_id, pos);
        world::set_component::<Direction>(spaceship_id, direction);
        ship.last_moved_at = get_block_timestamp();

        if ship.reference_body != DEFAULT_REFERENCE_BODY_ID {
            let d2 = pos.x * pos.x + pos.y * pos.y + pos.z * pos.z;
            let planet = world::get_model::<Planet>(ship.reference_body);
            if d2 > planet.max_radius_squared {
                let planet_pos = world::get_component::<Position>(ship.reference_body);
                let new_pos = Position {
                    x: planet_pos.x + pos.x,
                    y: planet_pos.y + pos.y,
                    z: planet_pos.z + pos.z,
                };
                world::set_component::<Position>(spaceship_id, new_pos);
                ship.reference_body = DEFAULT_REFERENCE_BODY_ID;
            }
        } else {
            let planet_ids = get_known_planets();
            for planet_id in planet_ids.iter() {
                let planet = world::get_model::<Planet>(*planet_id);
                let planet_pos = world::get_component::<Position>(*planet_id);
                let d2 = (pos.x - planet_pos.x).pow(2)
                       + (pos.y - planet_pos.y).pow(2)
                       + (pos.z - planet_pos.z).pow(2);
                if d2 <= planet.max_radius_squared {
                    ship.reference_body = *planet_id;
                    let relative_pos = Position {
                        x: pos.x - planet_pos.x,
                        y: pos.y - planet_pos.y,
                        z: pos.z - planet_pos.z,
                    };
                    world::set_component::<Position>(spaceship_id, relative_pos);
                    break;
                }
            }
        }

        world::set_model::<Spaceship>(spaceship_id, ship);
    }

fn move_player(self: @ContractState, player_id: u128, direction: Direction) {
        let mut player = world::get_model::<Player>(player_id);
        let mut pos = world::get_component::<Position>(player_id);

        pos.x += direction.yaw;
        pos.y += direction.pitch;
        pos.z += direction.roll;

        world::set_component::<Position>(player_id, pos);
        world::set_component::<Direction>(player_id, direction);

        player.last_moved_at = get_block_timestamp();
        world::set_model::<Player>(player_id, player);
    }

}

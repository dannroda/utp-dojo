use crate::models::{Player, CollectableTracker, Vec3, InventoryItem};
use dojo::world::world;
use starknet::get_block_timestamp;

pub fn current_pos(pos: Vec3, dir: Vec3, last_move: u128, speed: u128) -> Vec3 {
    let current_time_u64 = get_block_timestamp();
    let current_time: u128 = current_time_u64.into();
    let time_delta = current_time - last_move;
    
    // Calculate the distance to move based on time_delta and speed
    let distance_u128 = time_delta * speed;
    let distance: i128 = distance_u128.try_into().unwrap();
    
    // Calculate the new position by adding the direction vector multiplied by the distance
    // Since dir is normalized, this gives us the correct direction of movement
    return Vec3 {
        x: pos.x + dir.x * distance,
        y: pos.y + dir.y * distance,
        z: pos.z + dir.z * distance,
    };
}

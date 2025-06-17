use super::models::{Player, CollectableTracker};
use dojo::world::world;

pub fn add_to_inventory(player_id: u128, item_type: u16) {
    let mut player = world::get_model::<Player>(player_id);
    let current = player.inventory.get(item_type).unwrap_or(0_u64);
    player.inventory.insert(item_type, current + 1);
    world::set_model::<Player>(player_id, player);
}

pub fn get_collectable_bitfield(area: felt252, collectable_type: u16) -> felt252 {
    let id = compute_tracker_id(area, collectable_type);
    match world::get_model::<CollectableTracker>(id) {
        Some(entry) => entry.bitfield,
        None => 0,
    }
}

pub fn set_collectable_bitfield(area: felt252, collectable_type: u16, bitfield: felt252) {
    let id = compute_tracker_id(area, collectable_type);
    let entry = CollectableTracker {
        area,
        collectable_type,
        bitfield,
    };
    world::set_model::<CollectableTracker>(id, entry);
}

fn compute_tracker_id(area: felt252, collectable_type: u16) -> u128 {
    (area as u128) * 1000 + collectable_type as u128
}
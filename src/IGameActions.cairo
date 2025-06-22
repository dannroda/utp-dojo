use crate::models::Vec3;
use starknet::ContractState;

pub trait IGameActions {
    fn spawn_spaceship(self: @T, spaceship_id: u128, player_id: u128, spawn_pos: Vec3);
    fn despawn_spaceship(self: @T, spaceship_id: u128, player_id: u128);
    fn board_spaceship(self: @T, spaceship_id: u128, player_id: u128);
    fn unboard_spaceship(self: @T, spaceship_id: u128, player_id: u128);
    fn move_spaceship(self: @T, spaceship_id: u128, position: Vec3, direction: Vec3);
    fn move_player(self: @T, player_id: u128, position: Vec3, direction: Vec3);
    fn collect_item(self: @T, player_id: u128, collectable_type: u16, collectable_index: u8);
}

trait IGameActions<T> {
    fn spawn_spaceship(self: @T, spaceship_id: u128, player_id: u128);
    fn despawn_spaceship(self: @T, spaceship_id: u128, player_id: u128);
    fn board_spaceship(self: @T, spaceship_id: u128, player_id: u128);
    fn unboard_spaceship(self: @T, spaceship_id: u128, player_id: u128);
    fn move_spaceship(self: @T, spaceship_id: u128, direction: Direction);
    fn move_player(self: @T, player_id: u128, direction: Direction);
}

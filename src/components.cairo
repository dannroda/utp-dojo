#[derive(Component)]
struct Position {
    x: felt252,
    y: felt252,
    z: felt252,
}

#[derive(Component)]
struct Direction {
    yaw: felt252,
    pitch: felt252,
    roll: felt252,
}

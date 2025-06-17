#[model]
pub struct Player {
    pub id: u128,
    pub reference_body: u128,
    pub last_moved_at: u64,
    inventory: LegacyMap<u16, u64>,
}

#[model]
pub struct Spaceship {
    pub id: u128,
    pub owner: u128,
    pub capacity: u32,
    pub passengers: Array<u128>,
    pub last_moved_at: u64,
    pub reference_body: u128,
    pub is_spawned: bool,
}

#[model]
pub struct Planet {
    pub id: u128,
    seed: felt252,
    pub max_radius_squared: u128,
    epoc: felt252,
}


#[derive(Model)]
struct CollectableTracker {
    area: felt252,
    collectable_type: u16,
    bitfield: felt252,
}

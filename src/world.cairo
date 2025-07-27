use crate::models::{Player, CollectableTracker, Vec3, InventoryItem};
use dojo::world::world;
use starknet::get_block_timestamp;
use core::num::traits::Pow;
use core::num::traits::Sqrt;

const FP_UNIT: i128 = 0x10000000000; // 2^40
const FP_UNIT_BITS: u8 = 40;

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

pub fn fp40_mul(a: i128, b: i128) -> i128 {

    let mut ret = a * b;
    ret = ret / 2_i128.pow(FP_UNIT_BITS.into());

    return ret;
}

pub fn abs_value(v: i128) -> u128 {
    if (v < 0) { return (v * -1).try_into().unwrap(); };

    return v.try_into().unwrap();
}

pub fn fp40_div(a: i128, b: i128) -> i128 {

    let a_abs256 = abs_value(a) * 2_u128.pow(FP_UNIT_BITS.into());
    let b_abs = abs_value(b);

    let abs_ret = a_abs256 / b_abs;
    let ret : i128 = abs_ret.try_into().unwrap();

    if ( (a < 0) != (b < 0) ) {
        return ret * -1;
    };

    return ret;
}

pub fn vec3_fp40_div_scalar(v1: Vec3, s: i128) -> Vec3 {

    let ret = Vec3 {

        x: fp40_div(v1.x, s),
        y: fp40_div(v1.y, s),
        z: fp40_div(v1.z, s),
    };

    return ret;
}

pub fn vec3_fp40_dist_sq(v1: Vec3, v2: Vec3) -> i128 {

    let dx = v1.x - v2.x;
    let dy = v1.y - v2.y;
    let dz = v1.z - v2.z;
    let distance_squared = fp40_mul(dx, dx) + fp40_mul(dy, dy) + fp40_mul(dz, dz);

    return distance_squared;
}

pub fn vec3_fp40_len_sq(vec: Vec3) -> i128 {

    let distance_squared = fp40_mul(vec.x, vec.x) + fp40_mul(vec.y, vec.y) + fp40_mul(vec.z, vec.z);

    return distance_squared;
}

pub fn vec3_fp40_len(vec: Vec3) -> i128 {

    let d2 : u128 = vec3_fp40_len_sq(vec).try_into().unwrap();
    let d = d2.sqrt();
    return d.into();
}

pub fn vec3_sub(v1: Vec3, v2: Vec3) -> Vec3 {

    return Vec3 {

        x: v1.x - v2.x,
        y: v1.y - v2.y,
        z: v1.z - v2.z,
    };
}

use crate::models::{Player, CollectableTracker, Vec3, InventoryItem};
use dojo::world::world;
use starknet::get_block_timestamp;
use core::num::traits::Pow;
use core::num::traits::Sqrt;

const FP_UNIT: i128 = 0x10000000000; // 2^40
const FP_UNIT_BITS: u8 = 40;

pub fn current_pos(pos: Vec3, dest: Vec3, dir: Vec3, last_move: u128, speed: u128) -> Vec3 {
    let current_time_u64 = get_block_timestamp();
    let current_time: u128 = current_time_u64.into();
    let time_delta : u128 = current_time - last_move;
    println!("last move {}, delta time {}", last_move, time_delta);
    
    // Calculate the distance to move based on time_delta and speed
    let distance_elapsed : u128 = time_delta * speed;
    let distance_elapsed_sq: u256 = fp40_sq(distance_elapsed.try_into().unwrap());

    let distance_to_dest_sqf: felt252 = vec3_fp40_dist_sq(pos, dest).try_into().unwrap();
    let distance_to_dest_sq: u256 = distance_to_dest_sqf.into();

    println!("distance to dest {}, distance in time {}", distance_to_dest_sq, distance_elapsed_sq);

    // if distance to destination is less than distance to travel based on time, return destination
    if (distance_to_dest_sq <= distance_elapsed_sq) {
        return dest;
    };

    // Calculate the new position by adding the direction vector multiplied by the distance
    // Since dir is normalized, this gives us the correct direction of movement
    let distancei :i128 = distance_elapsed.try_into().unwrap();
    return Vec3 {
        x: pos.x + fp40_mul(dir.x, distancei),
        y: pos.y + fp40_mul(dir.y, distancei),
        z: pos.z + fp40_mul(dir.z, distancei),
    };
}

pub fn fp40_mul(a: i128, b: i128) -> i128 {

    let mut ret = a * b;
    ret = ret / 2_i128.pow(FP_UNIT_BITS.into());

    return ret;
}

pub fn fp40_sq(a: i128) -> u256 {

    let abs : u256 = abs_value(a).into();
    let ret = (abs * abs) / 2_u256.pow(FP_UNIT_BITS.into());

    return ret;
}

pub fn fp40_sqrt(a: u128) -> u128 {

    let abs : u256 = a.into() * 2_u256.pow(FP_UNIT_BITS.into());
    let sqrt = abs.sqrt();

    return sqrt.try_into().unwrap();
}

pub fn abs_value(v: i128) -> u128 {
    if (v < 0) { return (v * -1).try_into().unwrap(); };

    return v.try_into().unwrap();
}

pub fn fp40_div(a: i128, b: i128) -> i128 {

    let a_abs256: u256 = (abs_value(a) * 2_u128.pow(FP_UNIT_BITS.into())).into();
    let b_abs: u256 = (abs_value(b)).into();

    let abs_ret = a_abs256 / b_abs;
    let uret : u128 = abs_ret.try_into().unwrap(); 
    let ret : i128 = uret.try_into().unwrap();

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
    let distance_squared: u128 = (fp40_sq(dx) + fp40_sq(dy) + fp40_sq(dz)).try_into().unwrap();

    return distance_squared.try_into().unwrap();
}

pub fn vec3_fp40_len_sq(vec: Vec3) -> i128 {

    let d2 = fp40_sq(vec.x) + fp40_sq(vec.y) + fp40_sq(vec.z);
    println!("len squared 256 is {}", d2);
    let distance_squared: u128 = d2.try_into().unwrap();

    return distance_squared.try_into().unwrap();
}

pub fn vec3_fp40_len(vec: Vec3) -> i128 {

    let d2 : u128 = vec3_fp40_len_sq(vec).try_into().unwrap();
    println!("d2 is {}", d2);
    let d = fp40_sqrt(d2);
    println!("distance is {}", d);
    return d.try_into().unwrap();
}

pub fn vec3_sub(v1: Vec3, v2: Vec3) -> Vec3 {

    return Vec3 {

        x: v1.x - v2.x,
        y: v1.y - v2.y,
        z: v1.z - v2.z,
    };
}

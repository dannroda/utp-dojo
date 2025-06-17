# Dojo Game Contract

This project implements a 3D world game on Starknet using Dojo, with players, spaceships, planets, and procedurally generated collectables.

## 🧰 Requirements

- [Scarb](https://docs.swmansion.com/scarb/)
- [Dojo CLI (sozo)](https://book.dojoengine.org/)
- [Katana](https://book.dojoengine.org/tools/katana/)

Install all tools:
```bash
curl -L https://install.dojoengine.org | bash
````

## 🚀 Getting Started

### 1. Start Local Devnet

```bash
katana
```

### 2. Build Contract

```bash
./scripts/build.sh
```

### 3. Deploy World + Systems

```bash
./scripts/deploy.sh
```

## 🗂 Project Structure

* `src/components.cairo` – Position and Direction components
* `src/models.cairo` – Models for players, spaceships, planets
* `src/GameActions.cairo` – Action implementations
* `src/IGameActions.cairo` – ABI interface
* `src/world.cairo` – World model logic

## ✨ Features

* Player and spaceship movement in 3D
* Planets with gravity radius and seeds
* Reference body switching
* Procedural collectable generation per area
* Inventory and item pickup



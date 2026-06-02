# void_blackmarket

A premium, player-owned black market resource for FiveM servers (supporting QBCore and ESX). Features an illegal shop, society-managed stock and pricing, a money laundering system with adjustable tax rates, a secure crafting bench, map blips filtered by ownership, and a modern glassmorphic NUI interface.

---

## 🌟 Features

*   **Job & Gang Ownership:** Markets are tied to organizations (jobs or gangs like `lostmc`, `cartel`) instead of individual citizen IDs.
*   **Illegal Shop:** 
    *   Stocked and priced directly by territory members.
    *   Dropdown inventory selector in the UI for easy stocking (automatically fetches and shows pocket items with helper quantities).
    *   Boss-controlled **Offline Access** toggle allows citizens to buy from stock when all owner members are offline.
*   **Money Laundering:**
    *   Clean marked bills/dirty accounts through the market's network (includes tactile animations and progress bars).
    *   Tax rate (5% - 30%) is dynamically set by the organization bosses.
    *   All collected laundering taxes are deposited directly into the market's safe box.
*   **Crafting Bench:**
    *   Material requirements checklist with automated checks.
    *   Progress indicators and in-game welding/crafting animations.
    *   Secure lock ensuring **only** the owning job/gang members can access the crafting bench.
*   **Filtered Map Blips:**
    *   Blips are only registered and visible to the members of the owning job or gang.
    *   Blips update dynamically in real-time when a player's job or gang changes without resetting the Suspicious Dealer NPC.
*   **Management Dashboard:**
    *   Withdraw accumulated clean cash from the safe box.
    *   Adjust tax rates and toggle offline access.
    *   Manage active shop stock and set unit selling prices.
*   **Premium NUI Panels:** 
    *   High-fidelity borderless dark glass theme custom-tailored for maximum immersion.
    *   Custom administrative in-game dashboard for creating and placing markets.

---

## 🛠️ Prerequisites & Dependencies

*   [ox_lib](https://github.com/overextended/ox_lib) (For points, callbacks, progress bars, and alert dialogs)
*   [void_bridge](https://github.com/Fae-Alchemy/void_bridge) (Unified framework wrapper for player data, jobs, gangs, and currency)
*   [oxmysql](https://github.com/overextended/oxmysql) (For persistent database storage)
*   **Inventory System:** Compatible with both `ox_inventory` and `qb-inventory`.

---

## 💾 Installation

1.  **Clone/Download:** Clone this repository into your server resources directory:
    ```bash
    git clone https://github.com/Fae-Alchemy/void_blackmarket.git
    ```
2.  **Database Setup:** Import the SQL schema from [db.sql](db.sql) into your database to create the `void_blackmarkets` table.
3.  **Config Adjustments:** Open [config.lua](config.lua) and configure item names, crafting recipes, washing speeds, and defaults to match your server's economy.
4.  **Startup:** Add the resource to your server startup sequence:
    ```cfg
    ensure void_blackmarket
    ```

---

## 🎮 Commands

### Admin Commands
*   `/createblackmarket` - Opens the dynamic glassmorphic creator dashboard. Spawns a suspicious dealer NPC at your exact location and saves it persistently to the database.
*   `/deleteblackmarket` - Checks for the nearest black market NPC within 5 meters and opens a deletion confirmation dialog.

---

## 💻 Tech Stack & Design

*   **NUI Front-End:** Pure HTML5, Vanilla CSS, and JavaScript.
*   **Aesthetics:** Dark Theme glassmorphism (`#120d23` void violet-black and `#150f24` accent colors) optimized to clip perfectly in FiveM's CEF browser without outlines or artifacts.

---

## 📝 License
Created by **Fae_Alchemy**. All rights reserved.

let activeMarketId = null;
let currentMarketData = null;
let currentTab = "shop";
let itemVerifyTimeout = null;

// NUI Helper to perform POST requests with application/json headers
function postNUI(endpoint, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${endpoint}`, {
        method: "POST",
        headers: {
            "Content-Type": "application/json; charset=UTF-8"
        },
        body: JSON.stringify(data)
    }).then(res => {
        return res.text().then(text => {
            try {
                return JSON.parse(text);
            } catch (e) {
                return text;
            }
        });
    }).catch(err => {
        console.error(`postNUI error on endpoint ${endpoint}:`, err);
        return { success: false, message: "Communication error." };
    });
}

// DOM Elements
const wrapper = document.getElementById("market-wrapper");
const container = document.getElementById("market-container");
const navTabs = document.querySelectorAll(".nav-tab");
const tabPanes = document.querySelectorAll(".tab-pane");

const marketTitle = document.getElementById("market-title");
const ownerJobLabel = document.getElementById("owner-job-label");
const playerCashDisplay = document.getElementById("player-cash");

// Search & Grids
const shopSearch = document.getElementById("shop-search");
const shopItemsContainer = document.getElementById("shop-items-container");
const craftingItemsContainer = document.getElementById("crafting-items-container");

// Money Wash Elements
const washTaxDisplay = document.getElementById("wash-tax-display");
const dirtyMoneyDisplay = document.getElementById("dirty-money-display");
const dirtyMoneyType = document.getElementById("dirty-money-type");
const washInputAmount = document.getElementById("wash-input-amount");
const washMaxBtn = document.getElementById("wash-max-btn");
const washReceiptCard = document.getElementById("wash-receipt-card");
const receiptAmount = document.getElementById("receipt-amount");
const receiptTaxPercent = document.getElementById("receipt-tax-percent");
const receiptFee = document.getElementById("receipt-fee");
const receiptPayout = document.getElementById("receipt-payout");
const washSubmitBtn = document.getElementById("wash-submit-btn");

// Management Elements
const mgmtTabBtn = document.getElementById("mgmt-tab-btn");
const mgmtBalance = document.getElementById("mgmt-balance");
const mgmtWithdrawBtn = document.getElementById("mgmt-withdraw-btn");
const mgmtTaxSlider = document.getElementById("mgmt-tax-slider");
const mgmtTaxVal = document.getElementById("mgmt-tax-val");
const mgmtOfflineToggle = document.getElementById("mgmt-offline-toggle");
const mgmtSaveSettings = document.getElementById("mgmt-save-settings");
const mgmtStockList = document.getElementById("mgmt-stock-list");
const stockDepositBtn = document.getElementById("stock-deposit-btn");

// Deposit Modal Elements
const stockModal = document.getElementById("stock-modal");
const modalClose = document.getElementById("modal-close");
const modalItemName = document.getElementById("modal-item-name");
const modalItemVerify = document.getElementById("modal-item-verify");
const modalItemQty = document.getElementById("modal-item-qty");
const modalItemPrice = document.getElementById("modal-item-price");
const modalSubmit = document.getElementById("modal-submit");

const closeBtn = document.getElementById("close-btn");

// Creator DOM Elements
const creatorWrapper = document.getElementById("creator-wrapper");
const creatorCloseBtn = document.getElementById("creator-close-btn");
const creatorSubmitBtn = document.getElementById("creator-submit-btn");

const creatorName = document.getElementById("creator-name");
const creatorLabel = document.getElementById("creator-label");
const creatorJob = document.getElementById("creator-job");
const creatorPed = document.getElementById("creator-ped");
const creatorBlipSprite = document.getElementById("creator-blip-sprite");
const creatorBlipColor = document.getElementById("creator-blip-color");
const creatorBlipScale = document.getElementById("creator-blip-scale");


// --- UTILITY TOAST NOTIFICATION ---
function showToast(message, type = "info") {
    const toast = document.getElementById("toast");
    const toastIcon = toast.querySelector(".toast-icon");
    const toastTitle = toast.querySelector(".toast-title");
    const toastBody = toast.querySelector(".toast-body");
    
    // Set icon & color class
    toastIcon.className = "toast-icon fa-solid";
    if (type === "success") {
        toastIcon.classList.add("fa-circle-check", "success");
        toastTitle.innerText = "Success";
    } else if (type === "error") {
        toastIcon.classList.add("fa-circle-xmark", "error");
        toastTitle.innerText = "Error";
    } else {
        toastIcon.classList.add("fa-circle-info", "info");
        toastTitle.innerText = "System Notification";
    }
    
    toastBody.innerText = message;
    
    // Show toast
    toast.className = ""; // Reset transition classes
    setTimeout(() => {
        toast.classList.add("toast-hidden");
    }, 4000);
}

// --- GLOBAL NUI MESSAGES LISTENERS ---
window.addEventListener("message", function (event) {
    const action = event.data.action;
    const data = event.data.data;
    const imgPath = event.data.imagePath;
    
    if (action === "openMarket") {
        activeMarketId = data.marketId;
        currentMarketData = data;
        if (imgPath) currentMarketData.imagePath = imgPath;
        
        setupMarketUI();
        wrapper.style.display = "flex";
        switchTab("shop");
    } else if (action === "refreshMarket") {
        currentMarketData = data;
        if (imgPath) currentMarketData.imagePath = imgPath;
        setupMarketUI();
    } else if (action === "openCreator") {
        creatorName.value = "";
        creatorLabel.value = "";
        creatorJob.value = "";
        creatorPed.value = "g_m_m_mexboss_01";
        creatorBlipSprite.value = "501";
        creatorBlipColor.value = "1";
        creatorBlipScale.value = "0.8";
        
        creatorWrapper.style.display = "flex";
    }
});

// ESC Close handler
window.addEventListener("keydown", function (e) {
    if (e.key === "Escape") {
        closeUI();
    }
});

closeBtn.addEventListener("click", closeUI);

function closeUI() {
    wrapper.style.display = "none";
    creatorWrapper.style.display = "none";
    postNUI("closeUI");
}

// Creator event handlers
creatorCloseBtn.addEventListener("click", () => {
    creatorWrapper.style.display = "none";
    postNUI("closeUI");
});

creatorSubmitBtn.addEventListener("click", () => {
    const name = creatorName.value.trim().toLowerCase();
    const label = creatorLabel.value.trim();
    const ownerJob = creatorJob.value.trim().toLowerCase();
    const pedModel = creatorPed.value.trim();
    const blipSprite = parseInt(creatorBlipSprite.value) || 501;
    const blipColor = parseInt(creatorBlipColor.value) || 1;
    const blipScale = parseFloat(creatorBlipScale.value) || 0.8;
    
    if (name === "" || label === "" || ownerJob === "" || pedModel === "") {
        showToast("Please fill out all required fields.", "error");
        return;
    }
    
    creatorWrapper.style.display = "none";
    
    postNUI("submitCreateMarket", {
        name: name,
        label: label,
        ownerJob: ownerJob,
        pedModel: pedModel,
        blipSprite: blipSprite,
        blipColor: blipColor,
        blipScale: blipScale
    }).then(() => {
        // Callback completed
    });
});

// --- TAB SYSTEM CONFIG ---
navTabs.forEach(tab => {
    tab.addEventListener("click", () => {
        const target = tab.getAttribute("data-tab");
        switchTab(target);
    });
});

function switchTab(tabId) {
    if (tabId === "crafting" && !currentMarketData.isOwnerMember) {
        showToast("Access Denied: Crafting bench is locked to territory members.", "error");
        return;
    }
    
    currentTab = tabId;
    
    navTabs.forEach(t => {
        if (t.getAttribute("data-tab") === tabId) {
            t.classList.add("active");
        } else {
            t.classList.remove("active");
        }
    });
    
    tabPanes.forEach(p => {
        if (p.getAttribute("id") === `pane-${tabId}`) {
            p.classList.add("active");
        } else {
            p.classList.remove("active");
        }
    });
    
    if (tabId === "shop") {
        renderShop();
    } else if (tabId === "crafting") {
        renderCrafting();
    } else if (tabId === "wash") {
        resetWashInput();
    } else if (tabId === "management") {
        renderManagement();
    }
}

// --- SETUP BASE UI STATS ---
function setupMarketUI() {
    marketTitle.innerText = currentMarketData.label;
    ownerJobLabel.innerText = currentMarketData.ownerJob.toUpperCase();
    playerCashDisplay.innerText = `$${currentMarketData.playerCash.toLocaleString()}`;
    
    // Toggle management tab visibility based on job status
    if (currentMarketData.isOwnerBoss) {
        mgmtTabBtn.classList.remove("hidden");
    } else {
        mgmtTabBtn.classList.add("hidden");
        if (currentTab === "management") {
            switchTab("shop");
        }
    }
    
    // Toggle crafting tab style based on owner membership
    const craftingTabBtn = document.querySelector('[data-tab="crafting"]');
    if (currentMarketData.isOwnerMember) {
        craftingTabBtn.classList.remove("locked-tab");
        craftingTabBtn.querySelector("span").innerText = "Crafting Bench";
        craftingTabBtn.querySelector("i").className = "fa-solid fa-hammer";
    } else {
        craftingTabBtn.classList.add("locked-tab");
        craftingTabBtn.querySelector("span").innerText = "Crafting (Locked)";
        craftingTabBtn.querySelector("i").className = "fa-solid fa-lock";
        if (currentTab === "crafting") {
            switchTab("shop");
        }
    }
    
    // Dynamic lists rendering depending on active screen
    if (currentTab === "shop") renderShop();
    else if (currentTab === "crafting") renderCrafting();
    else if (currentTab === "management") renderManagement();
    
    // Laundering display refresh
    washTaxDisplay.innerText = `${currentMarketData.taxRate}%`;
    dirtyMoneyDisplay.innerText = `$${currentMarketData.dirtyMoney.toLocaleString()}`;
    dirtyMoneyType.innerText = currentMarketData.dirtyMoneyType === "account" 
        ? `${currentMarketData.dirtyMoneyAccount.toUpperCase()} account`
        : `${currentMarketData.dirtyMoneyName.replace("_", " ")} stacks`;
}

// --- RENDER 1: SHOP ITEMS ---
function renderShop() {
    shopItemsContainer.innerHTML = "";
    const query = shopSearch.value.toLowerCase();
    
    const filtered = currentMarketData.items.filter(item => {
        return item.name.toLowerCase().includes(query) || item.label.toLowerCase().includes(query);
    });
    
    if (filtered.length === 0) {
        shopItemsContainer.innerHTML = `
            <div class="empty-shop-msg">
                <i class="fa-solid fa-box-open"></i>
                <p>No illegal merchandise in stock</p>
            </div>
        `;
        return;
    }
    
    filtered.forEach(item => {
        const card = document.createElement("div");
        card.className = "shop-card";
        
        const isOutOfStock = item.stock <= 0;
        const stockText = isOutOfStock ? "SOLD OUT" : `Stock: ${item.stock}`;
        const stockClass = isOutOfStock ? "shop-card-stock out-of-stock" : "shop-card-stock";
        
        const imagePath = currentMarketData.imagePath ? `${currentMarketData.imagePath}${item.name}.png` : `nui://ox_inventory/web/images/${item.name}.png`;
        
        card.innerHTML = `
            <img class="shop-card-img" src="${imagePath}" onerror="this.src='https://cdn-icons-png.flaticon.com/512/3081/3081840.png';" alt="${item.label}">
            <span class="${stockClass}">${stockText}</span>
            <h3 class="shop-card-title">${item.label}</h3>
            
            <div class="shop-card-footer">
                <span class="shop-card-price">$${item.price.toLocaleString()}</span>
                <div class="stepper-wrapper" style="display: ${isOutOfStock ? 'none' : 'flex'}; margin-right: 8px;">
                    <input type="number" class="card-qty-input" min="1" max="${item.stock}" value="1" style="width: 50px; background: rgba(0,0,0,0.3); border: 1px solid var(--border-glass); border-radius: 6px; padding: 4px; color: #fff; text-align: center; font-family: var(--font-heading);">
                </div>
                <button class="shop-buy-btn ${isOutOfStock ? 'disabled' : ''}" ${isOutOfStock ? 'disabled' : ''}>
                    <span>BUY</span>
                    <i class="fa-solid fa-cart-shopping"></i>
                </button>
            </div>
        `;
        
        const buyBtn = card.querySelector(".shop-buy-btn");
        const qtyInput = card.querySelector(".card-qty-input");
        
        if (buyBtn && !isOutOfStock) {
            buyBtn.addEventListener("click", () => {
                const quantity = parseInt(qtyInput.value) || 1;
                purchaseItem(item.name, quantity);
            });
        }
        
        shopItemsContainer.appendChild(card);
    });
}

shopSearch.addEventListener("input", renderShop);

function purchaseItem(itemName, qty) {
    postNUI("purchaseItem", {
        marketId: activeMarketId,
        itemName: itemName,
        quantity: qty
    }).then(response => {
        if (response.success) {
            showToast("Purchase successful!", "success");
        } else {
            showToast(response.message || "Purchase failed.", "error");
        }
    });
}

// --- RENDER 2: CRAFTING ---
function renderCrafting() {
    craftingItemsContainer.innerHTML = "";
    
    currentMarketData.recipes.forEach(recipe => {
        const card = document.createElement("div");
        card.className = "crafting-card";
        
        const imagePath = currentMarketData.imagePath ? `${currentMarketData.imagePath}${recipe.item}.png` : `nui://ox_inventory/web/images/${recipe.item}.png`;
        const timeSec = (recipe.time / 1000).toFixed(0);
        
        let materialsHTML = "";
        let hasAllMaterials = true;
        
        recipe.materials.forEach(mat => {
            const isSufficient = mat.current >= mat.required;
            if (!isSufficient) hasAllMaterials = false;
            
            const tagClass = isSufficient ? "material-tag sufficient" : "material-tag insufficient";
            const iconClass = isSufficient ? "fa-solid fa-circle-check font-green" : "fa-solid fa-circle-xmark font-red";
            
            materialsHTML += `
                <div class="${tagClass}">
                    <i class="${iconClass}"></i>
                    <span>${mat.label}: <span class="mat-count">${mat.current}/${mat.required}</span></span>
                </div>
            `;
        });
        
        card.innerHTML = `
            <div class="crafting-info">
                <img class="crafting-item-img" src="${imagePath}" onerror="this.src='https://cdn-icons-png.flaticon.com/512/3081/3081840.png';" alt="${recipe.label}">
                <div class="crafting-details">
                    <h3>${recipe.label}</h3>
                    <span class="crafting-time">
                        <i class="fa-regular fa-clock"></i>
                        Craft duration: ${timeSec} seconds
                    </span>
                </div>
            </div>
            
            <div class="materials-wrapper">
                ${materialsHTML}
            </div>
            
            <button class="craft-btn ${hasAllMaterials ? '' : 'disabled'}" ${hasAllMaterials ? '' : 'disabled'}>
                <span>CRAFT</span>
                <i class="fa-solid fa-screwdriver-wrench"></i>
            </button>
        `;
        
        const craftBtn = card.querySelector(".craft-btn");
        if (craftBtn && hasAllMaterials) {
            craftBtn.addEventListener("click", () => {
                craftItem(recipe.item, recipe.label, recipe.time);
            });
        }
        
        craftingItemsContainer.appendChild(card);
    });
}

function craftItem(itemName, label, duration) {
    // Hide UI wrapper before triggering progress bar
    wrapper.style.display = "none";
    
    postNUI("craftItem", {
        marketId: activeMarketId,
        itemName: itemName,
        label: label,
        duration: duration
    }).then(response => {
        if (response.success) {
            showToast("Item crafted successfully!", "success");
        } else {
            showToast(response.message || "Crafting failed.", "error");
        }
    });
}

// --- LAUNDERING LOGIC ---
function resetWashInput() {
    washInputAmount.value = "";
    washReceiptCard.style.display = "none";
    washSubmitBtn.classList.add("disabled");
    washSubmitBtn.disabled = true;
}

washMaxBtn.addEventListener("click", () => {
    washInputAmount.value = currentMarketData.dirtyMoney;
    updateWashReceipt();
});

washInputAmount.addEventListener("input", updateWashReceipt);

function updateWashReceipt() {
    const val = parseInt(washInputAmount.value) || 0;
    
    if (val <= 0 || val > currentMarketData.dirtyMoney) {
        washReceiptCard.style.display = "none";
        washSubmitBtn.classList.add("disabled");
        washSubmitBtn.disabled = true;
        return;
    }
    
    const tax = currentMarketData.taxRate;
    const fee = Math.floor(val * (tax / 100));
    const payout = val - fee;
    
    receiptAmount.innerText = `$${val.toLocaleString()}`;
    receiptTaxPercent.innerText = tax;
    receiptFee.innerText = `-$${fee.toLocaleString()}`;
    receiptPayout.innerText = `$${payout.toLocaleString()}`;
    
    washReceiptCard.style.display = "flex";
    washSubmitBtn.classList.remove("disabled");
    washSubmitBtn.disabled = false;
}

washSubmitBtn.addEventListener("click", () => {
    const val = parseInt(washInputAmount.value) || 0;
    if (val <= 0) return;
    
    wrapper.style.display = "none";
    
    postNUI("washMoney", {
        marketId: activeMarketId,
        amount: val
    }).then(response => {
        if (response.success) {
            showToast("Money cleaned successfully!", "success");
        } else {
            showToast(response.message || "Washing transaction failed.", "error");
        }
    });
});

// --- RENDER 4: MANAGEMENT ---
function renderManagement() {
    mgmtBalance.innerText = `$${currentMarketData.balance.toLocaleString()}`;
    mgmtTaxSlider.value = currentMarketData.taxRate;
    mgmtTaxVal.innerText = `${currentMarketData.taxRate}%`;
    mgmtOfflineToggle.checked = currentMarketData.offlineAccess;
    
    renderStockTable();
}

mgmtTaxSlider.addEventListener("input", () => {
    mgmtTaxVal.innerText = `${mgmtTaxSlider.value}%`;
});

mgmtSaveSettings.addEventListener("click", () => {
    postNUI("updateSettings", {
        marketId: activeMarketId,
        taxRate: parseInt(mgmtTaxSlider.value),
        offlineAccess: mgmtOfflineToggle.checked
    }).then(response => {
        if (response.success) {
            showToast("Territory settings saved!", "success");
        } else {
            showToast(response.message || "Failed to update settings.", "error");
        }
    });
});

let numberModalCallback = null;

function openNumberModal(title, label, defaultValue, maxVal, callback) {
    document.getElementById("number-modal-title").innerText = title;
    document.getElementById("number-modal-label").innerText = label;
    const input = document.getElementById("number-modal-input");
    input.value = defaultValue;
    if (maxVal !== null) {
        input.max = maxVal;
    } else {
        input.removeAttribute("max");
    }
    numberModalCallback = callback;
    document.getElementById("number-modal").style.display = "flex";
}

document.getElementById("number-modal-close").addEventListener("click", () => {
    document.getElementById("number-modal").style.display = "none";
});

document.getElementById("number-modal-submit").addEventListener("click", () => {
    const val = parseInt(document.getElementById("number-modal-input").value) || 0;
    if (val <= 0) {
        showToast("Invalid value entered.", "error");
        return;
    }
    const maxValStr = document.getElementById("number-modal-input").getAttribute("max");
    if (maxValStr) {
        const maxVal = parseInt(maxValStr);
        if (val > maxVal) {
            showToast(`Value cannot exceed ${maxVal.toLocaleString()}`, "error");
            return;
        }
    }
    if (numberModalCallback) {
        numberModalCallback(val);
    }
    document.getElementById("number-modal").style.display = "none";
});

mgmtWithdrawBtn.addEventListener("click", () => {
    openNumberModal(
        "Withdraw Funds",
        `Enter clean cash amount to withdraw (Available: $${currentMarketData.balance.toLocaleString()}):`,
        currentMarketData.balance,
        currentMarketData.balance,
        (amountVal) => {
            postNUI("withdrawFunds", {
                marketId: activeMarketId,
                amount: amountVal
            }).then(response => {
                if (response.success) {
                    showToast(`Withdrew $${amountVal.toLocaleString()} from safe box.`, "success");
                } else {
                    showToast(response.message || "Failed to withdraw funds.", "error");
                }
            });
        }
    );
});

// RENDER STOCK MANAGEMENT TABLE
function renderStockTable() {
    mgmtStockList.innerHTML = "";
    
    if (currentMarketData.items.length === 0) {
        mgmtStockList.innerHTML = `
            <tr>
                <td colspan="4" style="text-align: center; padding: 25px 0; color: var(--text-dim);">
                    Shop stock is empty. Click "+ Stock Item" to add merchandise.
                </td>
            </tr>
        `;
        return;
    }
    
    currentMarketData.items.forEach(item => {
        const row = document.createElement("tr");
        
        row.innerHTML = `
            <td><strong>${item.label}</strong> <span style="font-size: 10px; color: var(--text-dim); display: block;">(${item.name})</span></td>
            <td>${item.stock}</td>
            <td class="table-price">$${item.price.toLocaleString()}</td>
            <td>
                <div class="table-actions">
                    <button class="icon-btn btn-price" title="Update Price"><i class="fa-solid fa-tag"></i></button>
                    <button class="icon-btn btn-withdraw" title="Retrieve Stock"><i class="fa-solid fa-box-open"></i></button>
                </div>
            </td>
        `;
        
        // Actions mapping
        row.querySelector(".btn-price").addEventListener("click", () => {
            openNumberModal(
                "Update Price",
                `Enter new unit selling price ($) for ${item.label}:`,
                item.price,
                null,
                (priceVal) => {
                    postNUI("updateStockPrice", {
                        marketId: activeMarketId,
                        itemName: item.name,
                        price: priceVal
                    }).then(response => {
                        if (response.success) {
                            showToast("Price updated successfully!", "success");
                        } else {
                            showToast(response.message || "Failed to update price.", "error");
                        }
                    });
                }
            );
        });
        
        row.querySelector(".btn-withdraw").addEventListener("click", () => {
            openNumberModal(
                "Retrieve Stock",
                `Enter quantity of ${item.label} to withdraw back to inventory (Available: ${item.stock}):`,
                item.stock,
                item.stock,
                (qtyVal) => {
                    postNUI("withdrawStock", {
                        marketId: activeMarketId,
                        itemName: item.name,
                        quantity: qtyVal
                    }).then(response => {
                        if (response.success) {
                            showToast("Stock retrieved back to pockets.", "success");
                        } else {
                            showToast(response.message || "Failed to retrieve stock.", "error");
                        }
                    });
                }
            );
        });
        
        mgmtStockList.appendChild(row);
    });
}

// --- DEPOSIT STOCK MODAL DIALOGS ---
stockDepositBtn.addEventListener("click", () => {
    // Empty dropdown and show loading state
    modalItemName.innerHTML = '<option value="" disabled selected>Loading pockets...</option>';
    modalItemVerify.innerText = "";
    modalItemVerify.className = "input-verify";
    modalItemQty.value = "1";
    modalItemQty.removeAttribute("max");
    modalItemPrice.value = "100";
    
    // Fetch pocket inventory items
    postNUI("getPlayerInventory").then(invList => {
        modalItemName.innerHTML = "";
        
        if (!invList || invList.length === 0) {
            modalItemName.innerHTML = '<option value="" disabled selected>No items in pockets</option>';
            return;
        }
        
        // Default prompt
        modalItemName.innerHTML = '<option value="" disabled selected>Choose item...</option>';
        
        // Sort alphabetically by label
        invList.sort((a, b) => a.label.localeCompare(b.label));
        
        invList.forEach(item => {
            const opt = document.createElement("option");
            opt.value = item.name;
            opt.innerText = `${item.label} (x${item.amount})`;
            opt.setAttribute("data-max", item.amount);
            modalItemName.appendChild(opt);
        });
    }).catch(err => {
        modalItemName.innerHTML = '<option value="" disabled selected>Failed to load inventory</option>';
    });
    
    stockModal.style.display = "flex";
});

modalClose.addEventListener("click", () => {
    stockModal.style.display = "none";
});

// Update the verify text when selecting an item to show pocket count, and clamp max quantity
modalItemName.addEventListener("change", () => {
    const selectedOpt = modalItemName.options[modalItemName.selectedIndex];
    if (!selectedOpt || selectedOpt.value === "") {
        modalItemVerify.innerText = "";
        modalItemQty.removeAttribute("max");
        return;
    }
    
    const maxQty = parseInt(selectedOpt.getAttribute("data-max")) || 1;
    modalItemQty.max = maxQty;
    modalItemQty.value = "1";
    modalItemVerify.innerText = `You have ${maxQty} in your pocket.`;
    modalItemVerify.className = "input-verify valid";
});

modalSubmit.addEventListener("click", () => {
    const itemName = modalItemName.value;
    const qty = parseInt(modalItemQty.value) || 0;
    const price = parseInt(modalItemPrice.value) || 0;
    
    if (!itemName || itemName === "" || qty <= 0 || price <= 0) {
        showToast("Please fill all form values correctly.", "error");
        return;
    }
    
    const selectedOpt = modalItemName.options[modalItemName.selectedIndex];
    const maxQty = selectedOpt ? parseInt(selectedOpt.getAttribute("data-max")) || 0 : 0;
    if (qty > maxQty) {
        showToast(`You only have ${maxQty} of this item in your pockets.`, "error");
        return;
    }
    
    postNUI("depositStock", {
        marketId: activeMarketId,
        itemName: itemName,
        quantity: qty,
        price: price
    }).then(response => {
        if (response.success) {
            showToast("Item successfully stocked!", "success");
            stockModal.style.display = "none";
        } else {
            showToast(response.message || "Failed to stock item.", "error");
        }
    });
});

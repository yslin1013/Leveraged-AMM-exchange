"use strict";

const updateTime = document.querySelector("#update-time");
const refreshButton = document.querySelector("#refresh-btn");
const connectButton = document.querySelector("#connect-btn");
const walletConnectButton = document.querySelector("#wallet-connect-btn");
const walletBalanceText = document.querySelector("#wallet-balance");
const walletTokenText = document.querySelector("#wallet-token");
const depositBalanceText = document.querySelector("#deposit-balance");
const remainingValueText = document.querySelector("#remaining-value");
const remainingValueUnitText = document.querySelector("#remaining-value-unit");
const lockedValueText = document.querySelector("#locked-value");

const tradingPairText = document.querySelector("#token-pair");
const tradingPairReservesText = document.querySelector("#token-pair-reserves");
const tradingPairCountText = document.querySelector("#token-pair-count");
const depositButton = document.querySelector("#deposit-btn");
const depositTokenSelect = document.querySelector("#deposit-token-select");
const depositTokenAmount = document.querySelector("#deposit-token-amount");
const withdrawButton = document.querySelector("#withdraw-btn");
const withdrawTokenSelect = document.querySelector("#withdraw-token-select");
const withdrawTokenAmount = document.querySelector("#withdraw-token-amount");

const requestSwapButton = document.querySelector("#request-swap-btn");
const collateralTokenSelect = document.querySelector("#collateral-token-select");
const targetTokenSelect = document.querySelector("#target-token-select");
const swapTokenAmount = document.querySelector("#swap-token-amount");
const positionModeSelect = document.querySelector("#position-mode-select");
const positionLeverageSelect = document.querySelector("#position-leverage-select");
const reducePositionSwitch = document.querySelector("#reduce-position-switch");

const crossPositionsTableBody = document.querySelector("#cross-position-table tbody");

const collateralSelectForwards = document.querySelector("#collateral-select-forwards");
const targetSelectForwards = document.querySelector("#target-select-forwards");
const leverageSelectForwards = document.querySelector("#leverage-select-forwards");
const collateralAmountForwards = document.querySelector("#collateral-amount-forwards");
const calculateButtonForwards = document.querySelector("#calculate-btn-forwards");

const collateralSelectReverse = document.querySelector("#collateral-select-reverse");
const targetSelectReverse = document.querySelector("#target-select-reverse");
const leverageSelectReverse = document.querySelector("#leverage-select-reverse");
const targetAmountReverse = document.querySelector("#target-amount-reverse");
const calculateButtonReverse = document.querySelector("#calculate-btn-reverse");
const calculateForSell = document.querySelector("#sell-checkbox");
const calculateResult = document.querySelector("#calculate-result");

document.addEventListener("DOMContentLoaded", async () => await loadContractAddress());

connectButton.addEventListener("click", async () => await connectWallet());
refreshButton.addEventListener("click", async () => await refreshData());
depositButton.addEventListener("click", async () => await depositTokens());
withdrawButton.addEventListener("click", async () => await withdrawTokens());
requestSwapButton.addEventListener("click", async () => await requestTokenSwap());

calculateButtonForwards.addEventListener("click", async () => {
  await calculateTargetFromCollateral()
});
calculateButtonReverse.addEventListener("click", async () => {
  if (calculateForSell.checked) await calculateReturnedCollateral();
  else await calculateCollateralFromTarget();
});

positionModeSelect.addEventListener("change", async () => {
  resetAllFields();
  if (positionModeSelect.value == "0") {
    lockForCrossMode();
  } else {
    reducePositionSwitch.disabled = true;
  }
});

reducePositionSwitch.addEventListener("change", async () => {
  if (reducePositionSwitch.checked) {
    const [positionValue, , targetDecimals] = await getPositionCrossValue();
    swapTokenAmount.value = ethers.formatUnits(positionValue, targetDecimals);
    lockForCrossMode();
  }
});

function lockForCrossMode() {
  positionLeverageSelect.value = "10";
  positionLeverageSelect.disabled = true;
}

function resetAllFields() {
  reducePositionSwitch.disabled = false;
  reducePositionSwitch.checked = false;
  swapTokenAmount.disabled = false;
  positionLeverageSelect.disabled = false;
}
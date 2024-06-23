"use strict";

const serviceInfo = {};
const contractInstances = {};

(async function main() {
  if (!await checkMetaMask()) return;
  await loadServiceInfo();
})();


// ======= Functions for loading settings ======= //
/**
 * For contract ABIs defination, refer to the `contract-abi.js` file.
 * For contract configuration, refer to the `contract-config.js` file.
 * For contract addresses, refer to the `contract-address.json` file.
 */

async function loadServiceInfo() {
  try {
    serviceInfo.provider = new ethers.BrowserProvider(window.ethereum);
    serviceInfo.signer = await serviceInfo.provider.getSigner();
    serviceInfo.network = await serviceInfo.provider.getNetwork();
    serviceInfo.collateral = Object.keys(addressList)[0];
    serviceInfo.target = Object.keys(addressList)[1];
    serviceInfo.pair = `${serviceInfo.collateral}/${serviceInfo.target}`;
    console.log(`Network = ${serviceInfo.network.name}, Chain ID = ${serviceInfo.network.chainId}`);

    contractInstances[serviceInfo.collateral] = new ethers.Contract(
      addressList[serviceInfo.collateral], tokenContractABI, serviceInfo.signer
    );
    contractInstances[serviceInfo.target] = new ethers.Contract(
      addressList[serviceInfo.target], tokenContractABI, serviceInfo.signer
    );
    serviceInfo.collateralDecimals = await contractInstances[serviceInfo.collateral].decimals();
    serviceInfo.targetDecimals = await contractInstances[serviceInfo.target].decimals();

    serviceInfo.exchangeKey = "EXCH_ISOLATED";
    serviceInfo.exchangeSwapKey = "AMM_SWAP";
    contractInstances[serviceInfo.exchangeKey] = new ethers.Contract(
      addressList[serviceInfo.exchangeKey], ammContractABI, serviceInfo.signer
    );
    contractInstances[serviceInfo.exchangeSwapKey] = new ethers.Contract(
      addressList[serviceInfo.exchangeKey], swapOrderABI, serviceInfo.signer
    );
    serviceInfo.maxLeverage = await contractInstances[serviceInfo.exchangeKey].MAX_LEVERAGE();
    serviceInfo.isolatedMode = "1";
  } catch (error) {
    console.error(error);
  }
}


// ======= Functions triggered by Event listeners ======= //
/**
 * For DOM objects declaration, refer to the `components.js` file.
 */

async function connectWallet() {
  try {
    const accounts = await ethereum.request({ method: "eth_requestAccounts" });
    serviceInfo.account = accounts[0];
    await refreshData();
  } catch (error) {
    console.error(error);
  }
}

async function depositTokens() {
  try {
    if (!await checkWalletConnected()) return;
    const exchKey = serviceInfo.exchangeKey;
    const tokenSymbol = depositTokenSelect.value;
    const tokenAmount = depositTokenAmount.value;
    if (!tokenSymbol || !tokenAmount) {
      alert("Please select token and enter amount to deposit.");
      return;
    }

    const normalizedAmount = ethers.parseUnits(
      tokenAmount,
      serviceInfo.collateralDecimals
    );

    let tx = await contractInstances[tokenSymbol].approve(
      addressList[exchKey],
      normalizedAmount,
      txSettings
    );
    await tx.wait();

    tx = await contractInstances[exchKey].deposit(
      addressList[tokenSymbol],
      normalizedAmount,
      txSettings
    );
    await tx.wait();

    await refreshData();
  } catch (error) {
    console.error(error);
  }
}

async function withdrawTokens() {
  try {
    if (!await checkWalletConnected()) return;
    const exchKey = serviceInfo.exchangeKey;
    const tokenSymbol = withdrawTokenSelect.value;
    const tokenAmount = withdrawTokenAmount.value;
    if (!tokenSymbol || !tokenAmount) {
      alert("Please select token and enter amount to withdraw.");
      return;
    }

    const normalizedAmount = ethers.parseUnits(
      tokenAmount,
      serviceInfo.collateralDecimals
    );

    let tx = await contractInstances[exchKey].withdraw(
      addressList[tokenSymbol],
      normalizedAmount,
      txSettings
    );
    await tx.wait();

    await refreshData();
  } catch (error) {
    console.error(error);
  }
}

async function calculateTargetFromCollateral() {
  try {
    if (!await checkWalletConnected()) return;
    const exchKey = serviceInfo.exchangeKey;
    const collateralDecimals = serviceInfo.collateralDecimals;
    const targetDecimals = serviceInfo.targetDecimals;
    const amountOut = await contractInstances[exchKey].getAmountOutFromIn(
      addressList[collateralSelectForwards.value],
      addressList[targetSelectForwards.value],
      ethers.parseUnits(collateralAmountForwards.value, collateralDecimals),
      leverageSelectForwards.value
    );
    const result = removeDecimals(amountOut, targetDecimals, 6);
    calculateResult.innerHTML = ` => Result: ${result}`;
  } catch (error) {
    alert("Request Failed. Please check whether the fields are correct.");
    console.error(error);
  }
}

async function calculateCollateralFromTarget() {
  try {
    if (!await checkWalletConnected()) return;
    const exchKey = serviceInfo.exchangeKey;
    const collateralDecimals = serviceInfo.collateralDecimals;
    const targetDecimals = serviceInfo.targetDecimals;
    const amountIn = await contractInstances[exchKey].getAmountInForOut(
      addressList[collateralSelectReverse.value],
      addressList[targetSelectReverse.value],
      ethers.parseUnits(targetAmountReverse.value, targetDecimals),
      leverageSelectReverse.value
    );
    const result = removeDecimals(amountIn, collateralDecimals, 6);
    calculateResult.innerHTML = ` => Result: ${result}`;
  } catch (error) {
    alert("Request Failed. Please check whether the fields are correct.");
    console.error(error);
  }
}

async function calculateReturnedCollateral() {
  try {
    if (!await checkWalletConnected()) return;
    const exchKey = serviceInfo.exchangeKey;
    const collateralDecimals = serviceInfo.collateralDecimals;
    const targetDecimals = serviceInfo.targetDecimals;
    const [_, returnedAmount] = await contractInstances[exchKey].getAmountCollateralReturn(
      addressList[collateralSelectReverse.value],
      addressList[targetSelectReverse.value],
      ethers.parseUnits(targetAmountReverse.value, targetDecimals),
      leverageSelectReverse.value
    );
    const result = removeDecimals(returnedAmount, collateralDecimals, 6);
    calculateResult.innerHTML = ` => Result: ${result}`;
  } catch (error) {
    alert("Request Failed. Please check whether the fields are correct.");
    console.error(error);
  }
}

async function requestTokenSwap() {
  try {
    if (!await checkWalletConnected()) return;
    let tokenAmount = swapTokenAmount.value;
    let positionLeverage = positionLeverageSelect.value;
    let closePositionIndex = closePositionIndexText.value;
    const collateralToken = collateralTokenSelect.value;
    const targetToken = targetTokenSelect.value;
    const positionMode = positionModeSelect.value;
    const closePosition = closePositionSwitch.checked;
    const collateralDecimals = serviceInfo.collateralDecimals;
    const targetDecimals = serviceInfo.targetDecimals;
    const exchSwapKey = serviceInfo.exchangeSwapKey;

    if (!collateralToken || !targetToken || !positionMode) {
      alert("Please select tokens and position mode to swap.");
      return;
    }

    if (positionMode == serviceInfo.isolatedMode) {
      if (!closePosition) {
        // Check if the input amount is greater than the deposit balance
        closePositionIndex = 0; // NOTE: no pos index
        tokenAmount = ethers.parseUnits(tokenAmount, collateralDecimals);
        if (!await checkDepositBalance(tokenAmount)) return;
      } else {
        // Check if the input position index is valid
        if (!closePositionIndex || isNaN(closePositionIndex)) {
          alert("Please enter close position index.");
          return;
        }
        // Load position value and leverage
        [tokenAmount, positionLeverage,] = await getPositionIsolatedValue(closePositionIndex);
      }
    } else {
      alert("please select the position mode");
      return;
    }

    // Execute token swap
    const tx = await contractInstances[exchSwapKey].swap(
      {
        tokenA: addressList[collateralToken],
        tokenB: addressList[targetToken],
        amount: tokenAmount,
        leverage: positionLeverage,
        positionMode: positionMode,
        reducePosition: false,
        closePosition: closePosition,
        closePosIndex: closePositionIndex,
        txSettings
      }
    );
    await tx.wait();

    await refreshData();
  } catch (error) {
    alert("Request Failed. Please check whether the fields are correct.");
    console.error(error);
  }
}


// ======= Functions for loading data ======= //
/**
 * For DOM objects declaration, refer to the `components.js` file.
 */

async function refreshData() {
  try {
    if (!await checkWalletConnected()) return;
    const provider = serviceInfo.provider;
    const selectedAddress = serviceInfo.account;
    const collateralSymbol = serviceInfo.collateral;
    const collateralDecimals = serviceInfo.collateralDecimals;
    const targetSymbol = serviceInfo.target;
    const targetDecimals = serviceInfo.targetDecimals;
    const exchKey = serviceInfo.exchangeKey;
    const exchSwapKey = serviceInfo.exchangeSwapKey;

    const [
      nowDate, ethBalance, walletBalance, depositBalance, remainingValue, lockedValue, positionId
    ] = await Promise.all([
      new Date().toISOString().split("T"),
      provider.getBalance(selectedAddress),
      contractInstances[collateralSymbol].balanceOf(selectedAddress),
      contractInstances[exchKey].balances(selectedAddress, addressList[collateralSymbol]),
      contractInstances[exchKey].getAccountRemainingValue(selectedAddress, addressList[collateralSymbol], addressList[targetSymbol]),
      contractInstances[exchKey].getPositionWorthValue(selectedAddress, addressList[collateralSymbol], addressList[targetSymbol]),
      contractInstances[exchKey].getPositionId(addressList[collateralSymbol], addressList[targetSymbol])
    ]);
    walletConnectButton.innerHTML = `${selectedAddress} (${removeDecimals(ethBalance, 18)} ETH)`;
    walletBalanceText.innerHTML = `$${removeDecimals(walletBalance, collateralDecimals)}`;
    depositBalanceText.innerHTML = `$${removeDecimals(depositBalance, collateralDecimals)}`;
    walletTokenText.innerHTML = ` <i class="bi bi-coin me-1"></i> ${collateralSymbol} `;
    remainingValueText.innerHTML = `$${removeDecimals(remainingValue, collateralDecimals)}`;
    remainingValueUnitText.innerHTML = ` <i class="bi bi-coin me-1"></i> ${collateralSymbol} `;
    lockedValueText.innerHTML = `$${removeDecimals(lockedValue, collateralDecimals)}`;
    updateTime.innerHTML = `Update: ${nowDate[0]} ${nowDate[1].split(".")[0]}`;

    const [pairCount, pairPrice, pairInfo] = await Promise.all([
      contractInstances[exchKey].pairCount(),
      contractInstances[exchKey].getPairPrice(addressList[collateralSymbol], addressList[targetSymbol]),
      contractInstances[exchSwapKey].pairs(addressList[collateralSymbol], addressList[targetSymbol]),
    ]);
    const [pairSymbol, reserveA, reserveB] = pairInfo;
    tradingPairText.innerHTML = ` <i class="bi bi-currency-exchange me-1"></i> ${pairSymbol} `;
    tradingPairCountText.innerHTML = pairCount;
    tradingPairReservesText.innerHTML
      = `${removeDecimals(reserveB, collateralDecimals, 1)} / ${removeDecimals(reserveA, targetDecimals, 1)}`;

    await loadPositionsIsolated(positionId);
  } catch (error) {
    console.error(error);
  }
}

async function loadPositionsIsolated(positionId) {
  const selectedAddress = serviceInfo.account;
  const collateralSymbol = serviceInfo.collateral;
  const collateralDecimals = serviceInfo.collateralDecimals;
  const targetSymbol = serviceInfo.target;
  const targetDecimals = serviceInfo.targetDecimals;
  const exchKey = serviceInfo.exchangeKey;
  const exchSwapKey = serviceInfo.exchangeSwapKey;
  const spinners = `<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>`;

  const isolatedPositionsLength = await contractInstances[exchKey].getPositionsIsolatedLength(
    selectedAddress, addressList[collateralSymbol], addressList[targetSymbol]
  );
  isolatedPositionsTableBody.innerHTML = spinners;
  await sleep(1000);
  isolatedPositionsTableBody.innerHTML = "";

  for (let i = 0; i < isolatedPositionsLength; i++) {
    const [
      tradingPairSymbol, collateralAmount, collateralWorthValue, positionValue, leverage
    ] = await contractInstances[exchSwapKey].positionsIsolated(selectedAddress, positionId, i);

    const newRow = document.createElement("tr");
    newRow.innerHTML = `
      <th scope="row"><h6><span class="badge bg-secondary">${i}</span><h5></th>
      <td><span class="badge bg-primary">${tradingPairSymbol}</span></td>
      <td>${removeDecimals(collateralAmount, collateralDecimals, 8)}</td>
      <td>${removeDecimals(collateralWorthValue, collateralDecimals, 8)}</td>
      <td>${removeDecimals(positionValue, targetDecimals, 8)}</td>
      <td><h6><span class="badge bg-danger">${leverage}x</span></h6></td>
      <td><h6><span class="badge bg-success">Open</span></h6></td>
    `;
    isolatedPositionsTableBody.appendChild(newRow);
  }
}

async function getPositionIsolatedValue(positionIndex) {
  const selectedAddress = serviceInfo.account;
  const collateralSymbol = serviceInfo.collateral;
  const targetSymbol = serviceInfo.target;
  const targetDecimals = serviceInfo.targetDecimals;
  const exchKey = serviceInfo.exchangeKey;
  const exchSwapKey = serviceInfo.exchangeSwapKey;
  const positionId = await contractInstances[exchKey].getPositionId(
    addressList[collateralSymbol], addressList[targetSymbol]
  );
  const [, , , positionValue, leverage] = await contractInstances[exchSwapKey].positionsIsolated(
    selectedAddress, positionId, positionIndex
  );
  return [positionValue, leverage, targetDecimals];
}


// ======= Helper functions ======= //

async function checkMetaMask() {
  if (typeof window.ethereum == "undefined") {
    alert("MetaMask is not installed. Please install it and try again.");
    return false;
  }
  console.log(`MetaMask = ${ethereum.isMetaMask}`);
  return true;
}

async function checkWalletConnected() {
  if (ethereum.isMetaMask && serviceInfo.account) return true;
  else {
    alert("Please connect the wallet first.");
    return false;
  }
}

async function checkDepositBalance(tokenAmount) {
  const selectedAddress = serviceInfo.account;
  const collateralSymbol = serviceInfo.collateral;
  const exchKey = serviceInfo.exchangeKey;
  if (await contractInstances[exchKey].balances(selectedAddress, addressList[collateralSymbol]) < tokenAmount) {
    alert("Insufficient balance to swap.");
    return false;
  }
  return true;
}

function removeDecimals(amount, decimals, precision = 2) {
  const multipier = (10 ** precision);
  return Math.floor(Number(ethers.formatUnits(amount, decimals)) * multipier) / multipier;
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
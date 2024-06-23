const { readFileSync, writeFileSync } = require("fs");

const deployedInfo = JSON.parse(readFileSync("./broadcast/LeveragedAMMExchange.s.sol/31337/run-latest.json", "utf8"))["returns"];

let addressList = {};
Object.entries(deployedInfo).forEach(([_, value], index) => {
  const tokens = ["DAI", "WETH", "BNB", "PERP", "EXCH_CROSS", "EXCH_ISOLATED"];
  if (index < tokens.length) {
    addressList[tokens[index]] = value["value"];
  }
});

console.log("Deployed contract addresses =", JSON.stringify(addressList, null, 2));
writeFileSync("./html/contract-address.json", JSON.stringify(addressList, null, 2));

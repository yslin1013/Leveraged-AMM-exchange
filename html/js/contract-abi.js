"use strict";

const tokenContractABI = [
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address account) view returns (uint256)",
  "function approve(address spender, uint256 amount) returns (bool)",
];

const ammContractABI = [
  "function MAX_LEVERAGE() view returns (uint8)",
  "function pairCount() view returns (uint256)",
  "function deposit(address collateralToken, uint256 amount)",
  "function withdraw(address collateralToken, uint256 amount)",
  "function balances(address account, address collateralToken) view returns (uint256)",
  "function getPairPrice(address tokenA, address tokenB) view returns (uint256)",
  "function getPositionId(address tokenA, address tokenB) pure returns (bytes32)",
  "function getAmountOutFromIn(address tokenA, address tokenB, uint256 amountIn, uint8 leverage) view returns (uint256)",
  "function getAmountInForOut(address tokenA, address tokenB, uint256 amountOut, uint8 leverage) view returns (uint256)",
  "function getAmountCollateralReturn(address tokenA, address tokenB, uint256 amount, uint8 leverage) view returns (uint256, uint256)",
  "function getAccountRemainingValue(address account, address tokenA, address tokenB) view returns (uint256)",
  "function getPositionWorthValue(address account, address tokenA, address tokenB) view returns (uint256)",
  "function getPositionsIsolatedLength(address account, address tokenA, address tokenB) view returns (uint256)",
];

const swapOrderABI = [
  {
    "type": "function",
    "name": "swap",
    "inputs": [
      {
        "name": "swapOrder",
        "type": "tuple",
        "internalType": "struct LeveragedAMMExchange.Order",
        "components": [
          {
            "name": "tokenA",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "tokenB",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "leverage",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "positionMode",
            "type": "uint8",
            "internalType": "enum LeveragedAMMExchange.Mode"
          },
          {
            "name": "reducePosition",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "closePosition",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "closePosIndex",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      },
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      }
    ],
    "stateMutability": "view",
    "type": "function",
    "name": "positionCross",
    "outputs": [
      {
        "name": "tradingPairSymbol",
        "type": "string",
        "internalType": "string"
      },
      {
        "internalType": "uint256",
        "name": "collateralAmount",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "collateralWorthValue",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "positionValue",
        "type": "uint256"
      },
      {
        "internalType": "uint8",
        "name": "leverage",
        "type": "uint8"
      }
    ]
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      },
      {
        "internalType": "bytes32",
        "name": "",
        "type": "bytes32"
      },
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function",
    "name": "positionsIsolated",
    "outputs": [
      {
        "name": "tradingPairSymbol",
        "type": "string",
        "internalType": "string"
      },
      {
        "internalType": "uint256",
        "name": "collateralAmount",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "collateralWorthValue",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "positionValue",
        "type": "uint256"
      },
      {
        "internalType": "uint8",
        "name": "leverage",
        "type": "uint8"
      }
    ]
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      },
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function",
    "name": "pairs",
    "outputs": [
      {
        "name": "tradingPairSymbol",
        "type": "string",
        "internalType": "string"
      },
      {
        "internalType": "uint256",
        "name": "reserveA",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "reserveB",
        "type": "uint256"
      }
    ]
  },
];
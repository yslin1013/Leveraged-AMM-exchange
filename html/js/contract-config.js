"use strict";

const txSettings = { gasLimit: 3000000 };

const addressList = {};

async function loadContractAddress() {
  fetch('contract-address.json')
    .then(response => response.json())
    .then(data => {
      Object.assign(addressList, data);
      console.log("Contract address list loaded:", addressList);
    })
    .catch(error => console.error("Error fetching JSON data:", error));
}

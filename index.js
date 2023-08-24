const express = require("express");
const { ethers } = require("ethers");
const fs = require("fs");
const cors = require("cors")

const app = express();
const port = 3000;
app.use(cors())

// Create a new instance of JsonRpcProvider
const provider = new ethers.providers.JsonRpcProvider(
  "https://sepolia.mode.network/"
);

// The address of the deployed smart contract
const contractAddress = "0x356C57Bc82ef554b51129b08fC0FA5d2Cf1eD93b";

// Load the ABI from the external JSON file
const abiFilePath = "artifacts/contracts/NameRegistry.sol/NameRegistry.json";
const abiJson = JSON.parse(fs.readFileSync(abiFilePath, "utf8"));
const contractAbi = abiJson.abi;

const contract = new ethers.Contract(contractAddress, contractAbi, provider);

app.get("/reverse/:name", async (req, res) => {
  try {
    const nameWithTld = req.params.name;
    // console.log(nameWithTld);

    const Address = await contract.resolveName(nameWithTld);
    res.json({ Address });
  } catch (error) {
    res.status(500).json({ error: "An error occurred" });
  }
});

app.get("/resolve/:address", async (req, res) => {
  try {
    const address = req.params.address;
    // console.log(nameWithTld);

    const Name = await contract.reverseResolver(address);
    res.json({ Name });
  } catch (error) {
    res.status(500).json({ error: "An error occurred" });
  }
});

app.listen(port, () => {
  console.log(`API listening at http://localhost:${port}`);
});

require('dotenv').config();
const RandomGenerator = artifacts.require("RandomGenerator");
const owner = process.env.OWNER;
const seed = process.env.SEED;

module.exports = function (deployer) {
  deployer.deploy(RandomGenerator, seed, owner);
};

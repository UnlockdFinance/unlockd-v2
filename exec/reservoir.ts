import Axios from 'axios';
import Spinner from './spinner';
import BigNumber from 'bignumber.js';
import fs from 'fs';
import {ethers} from 'ethers';

const PERCENT = 10;

const ERC20ABI = [
  {
    inputs: [
      {
        internalType: 'address',
        name: 'spender',
        type: 'address',
      },
      {
        internalType: 'uint256',
        name: 'amount',
        type: 'uint256',
      },
    ],
    name: 'approve',
    outputs: [
      {
        internalType: 'bool',
        name: '',
        type: 'bool',
      },
    ],
    stateMutability: 'nonpayable',
    type: 'function',
  },
];
// Load config
const RPC_MAINNET = process.env.RPC_MAINNET;
if (!RPC_MAINNET) new Error('RPC_MAINNET needed on .env');
const RESERVOIR_API_KEY = process.env.RESERVOIR_API_KEY;
if (!RESERVOIR_API_KEY) new Error('RESERVOIR_API_KEY needed on .env');

const provider = new ethers.providers.StaticJsonRpcProvider(RPC_MAINNET);

const getPath = (action: string, currency: string) => {
  return `./exec/${action}_test_data_${currency}.json`;
};

const getLast = (arr: any[]) => {
  return arr[arr.length - 1];
};
const getCalculatedPrice = (price: string, currency: string) => {
  if (currency === '0x0000000000000000000000000000000000000000') return price;
  const denom = new BigNumber(10).pow(TOKENS[currency]);
  const slippage = new BigNumber(price)
    .div(ethers.utils.parseUnits('100', TOKENS[currency]).toString())
    .multipliedBy(PERCENT);
  const calulatedPrice = new BigNumber(price)
    .plus(slippage.multipliedBy(denom).toFixed(0))
    .toString();
  return calulatedPrice;
};
const decodeApproval = (data: string) => {
  const iface = new ethers.utils.Interface(ERC20ABI);
  const results = iface.decodeFunctionData('approve', data);
  return results[0];
};

function numHex(s: string) {
  // @ts-ignore
  var a = s.toString(16);
  while (a.length < 4) {
    a = '0' + a;
  }
  return a;
}

const TOKENS: Record<string, number> = {
  '0x0000000000000000000000000000000000000000': 18, // RAW Etherum
  '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2': 18, // WETH
  '0x6B175474E89094C44Da98b954EedeAC495271d0F': 18, // DAI
};

interface Item {
  quantity: number;
  token: string;
}

interface APIData {
  items: Item[];
  onlyPath: boolean;
  normalizeRoyalties: boolean;
  allowInactiveOrderIds: boolean;
  partial: boolean;
  skipBalanceCheck: boolean;
  excludeEOA: boolean;
  taker: string;
  forceRouter: boolean;
  currency: string;
  swapProvider: string;
}
// Useful tool to decode data https://calldata-decoder.apoorv.xyz/
// OpenSea https://opensea.io/assets/ethereum/0xed5af388653567af2f388e6224dc7c4b3241c544/4753
const getBuyData = async (nftToken: string, taker: string, currency: string) => {
  const data: APIData = {
    items: [
      {
        quantity: 1,
        token: nftToken,
      },
    ],
    onlyPath: false,
    normalizeRoyalties: true,
    allowInactiveOrderIds: false,
    partial: false,
    skipBalanceCheck: true,
    excludeEOA: true,
    taker: taker,
    forceRouter: true,
    currency: currency,
    swapProvider: 'uniswap',
  };

  try {
    const result = await Axios.post('https://api.reservoir.tools/execute/buy/v7', data, {
      headers: {
        'x-api-key': RESERVOIR_API_KEY,
      },
    });

    // Alsways we return the last element
    return result.data;
  } catch (error) {
    Spinner.space();
    console.log(error);
    await Spinner.spinnerError();
    await Spinner.stopSpinner();
  }
};

const buy = async (str: any) => {
  await Spinner.updateSpinnerText('Check the market ...');
  const data = await getBuyData(str.nft, str.address, str.currency);
  const path = getLast(data.path);
  const steps = getLast(getLast(data.steps).items);
  await Spinner.stopSpinner();
  await Spinner.updateSpinnerText('Storing data ...');
  const filePath = getPath('buy', str.currency);

  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
  try {
    console.log('TEST');

    const blockNumber = await provider.getBlockNumber();
    console.log(path);
    // console.log('TOTAL : ',(new BigNumber(path.buyInRawQuote)).plus(slippage.multipliedBy(denom).toFixed(0)).toString());
    const calculatedPrice = getCalculatedPrice(
      path.buyInRawQuote || path.totalRawPrice,
      str.currency
    );
    console.log('CALCULATED PRICE: ', calculatedPrice);
    fs.writeFileSync(
      filePath,
      JSON.stringify({
        currency: str.currency,
        approval: data.steps.length > 1 ? decodeApproval(data.steps[0].items[0].data.data) : '0',
        approvalTo: data.steps[0].items[0].data.to,
        approvalData: data.steps[0].items[0].data.data,
        blockNumber: blockNumber.toString(),
        nftAsset: str.nft.split(':')[0],
        nftTokenId: str.nft.split(':')[1].toString(),
        from: steps.data.from,
        to: steps.data.to,
        data: steps.data.data,
        price: calculatedPrice, // TODO: We need to add 5%
        value: steps.data.value ? calculatedPrice : '0',
      }),
      {
        encoding: 'utf8',
        mode: 0o755,
      }
    );

    await Spinner.stopSpinner();
  } catch (error) {
    console.log('OLI');
    Spinner.space();
    console.log(error);
    await Spinner.spinnerError();
    await Spinner.stopSpinner();
  }
};

const getSellData = async (nftToken: string, taker: string, currency: string) => {
  const data: APIData = {
    items: [
      {
        quantity: 1,
        token: nftToken,
      },
    ],
    onlyPath: false,
    normalizeRoyalties: true,
    allowInactiveOrderIds: false,
    partial: false,
    skipBalanceCheck: true,
    excludeEOA: true,
    taker: taker,
    forceRouter: true,
    currency: currency,
    swapProvider: 'uniswap',
  };

  try {
    const result = await Axios.post('https://api.reservoir.tools/execute/sell/v7', data, {
      headers: {
        'x-api-key': RESERVOIR_API_KEY,
      },
    });

    // Alsways we return the last element
    return result.data;
  } catch (error) {
    Spinner.space();
    console.log(error);
    await Spinner.spinnerError();
    await Spinner.stopSpinner();
  }
};

const sell = async (str: any) => {
  await Spinner.updateSpinnerText('Check the market ...');
  const data = await getSellData(str.nft, str.address, str.currency);
  const path = getLast(data.path);
  const steps = getLast(getLast(data.steps).items);
  await Spinner.stopSpinner();
  await Spinner.updateSpinnerText('Storing data ...');
  const filePath = getPath('sell', str.currency);

  if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
  try {
    console.log();

    const blockNumber = await provider.getBlockNumber();
    console.log(path);
    // console.log('TOTAL : ',(new BigNumber(path.buyInRawQuote)).plus(slippage.multipliedBy(denom).toFixed(0)).toString());
    const calculatedPrice = getCalculatedPrice(
      path.buyInRawQuote || path.totalRawPrice,
      str.currency
    );
    console.log('CALCULATED PRICE: ', calculatedPrice);
    fs.writeFileSync(
      filePath,
      JSON.stringify({
        currency: str.currency,
        approval: '0',
        approvalTo: steps.data.to,
        approvalData: '0x',
        blockNumber: blockNumber.toString(),
        nftAsset: str.nft.split(':')[0],
        nftTokenId: str.nft.split(':')[1].toString(),
        from: steps.data.from,
        to: steps.data.to,
        data: steps.data.data,
        price: calculatedPrice, // TODO: We need to add 5%
        value: steps.data.value ? calculatedPrice : '0',
      }),
      {
        encoding: 'utf8',
        mode: 0o755,
      }
    );

    await Spinner.stopSpinner();
  } catch (error) {
    Spinner.space();
    console.log(error);
    await Spinner.spinnerError();
    await Spinner.stopSpinner();
  }
};
export const exec = async (str: any) => {
  console.log(str);
  if (str.nft && str.address && str.currency && !str.action)
    throw new Error('All params are required');
  switch (str.action) {
    case 'buy':
      await buy(str);
      break;
    case 'sell':
      await sell(str);
      break;
    default:
      throw new Error('NOT SUPORTED');
  }
};

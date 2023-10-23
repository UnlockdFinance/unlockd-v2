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

// SELL

// curl --request POST \
//      --url https://api.reservoir.tools/execute/sell/v7 \
//      --header 'accept: */*' \
//      --header 'content-type: application/json' \
//      --header 'x-api-key: 5a727dcb-53fc-5206-aaa8-5542c1730e4f' \
//      --data '
// {
//   "items": [
//     {
//       "quantity": 1,
//       "token": "0x740c178e10662bBb050BDE257bFA318dEfE3cabC:2368"
//     }
//   ],
//   "onlyPath": false,
//   "normalizeRoyalties": true,
//   "excludeEOA": false,
//   "allowInactiveOrderIds": false,
//   "partial": false,
//   "forceRouter": false,
//   "taker": "0xde48b7964f98336CFC5870890B3848A3aC9f0568"
// }
// '
/*

RESPONSE:
{
  "requestId": "cd8c1753-2980-4574-b174-17cd1475a10f",
  "steps": [
    {
      "id": "nft-approval",
      "action": "Approve NFT contract",
      "description": "Each NFT collection you want to trade requires a one-time approval transaction",
      "kind": "transaction",
      "items": []
    },
    {
      "id": "sale",
      "action": "Accept offer",
      "description": "To sell this item you must confirm the transaction and pay the gas fee",
      "kind": "transaction",
      "items": [
        {
          "status": "incomplete",
          "orderIds": [
            "0x5a6606a6b54e910a710e5cbb65a4b9db5ebcd02329b89b1cd420ca1f5adb0552"
          ],
          "data": {
            "from": "0xde48b7964f98336cfc5870890b3848a3ac9f0568",
            "to": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
            "data": "0xb88d4fde000000000000000000000000de48b7964f98336cfc5870890b3848a3ac9f05680000000000000000000000009561e33b68d7c21e4010f027d751d417127cc5b50000000000000000000000000000000000000000000000000000000000000940000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000005e4760f2a0b0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000200000000000000000000000009561e33b68d7c21e4010f027d751d417127cc5b50000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004e43278ef720000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000036000000000000000000000000000000000000000000000000000000000000003a00000000000000000000000000000000000000000000000000000000000000420000000000000000000000000de48b7964f98336cfc5870890b3848a3ac9f0568000000000000000000000000de48b7964f98336cfc5870890b3848a3ac9f0568000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000004800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012fe700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000bc4ca0eda7647a8ab7c2061c2e118a18a936f13d000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000041af51792cdcfab9bdc0239f1d1c274e0b2682ae0000000000000000000000000000000000000000000000000000000064e36f0f0000000000000000000000000000000000000000000000000000000064e372930000000000000000000000000000000000000000000000013841d58988ad400000000000000000000000000000000000000000000000000000000000000001e0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000009400000000000000000000000000000000000000000000000000000000000000041fe6123bd63b6eea64914ce85da870bcaded2045fdde2e70050b3f3356411951b627faf5cfab5af82cae40bf0cec07354b827d186d605b26285e38ac9a7b5db6d1b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000aae7ac476b117bccafe2f05f582906be44bc8ff100000000000000000000000000000000000000000000000007ce72237037880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001d4da48b00000000"
          }
        }
      ]
    }
  ],
  "errors": [],
  "path": [
    {
      "orderId": "0x5a6606a6b54e910a710e5cbb65a4b9db5ebcd02329b89b1cd420ca1f5adb0552",
      "contract": "0xbc4ca0eda7647a8ab7c2061c2e118a18a936f13d",
      "tokenId": "2368",
      "quantity": 1,
      "source": "looksrare.org",
      "currency": "0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
      "currencySymbol": "WETH",
      "currencyDecimals": 18,
      "quote": 21.82548,
      "rawQuote": "21825485000000000000",
      "totalPrice": 22.5005,
      "totalRawPrice": "22500500000000000000",
      "builtInFees": [
        {
          "bps": 50,
          "kind": "marketplace",
          "recipient": "0x1838de7d4e4e42c8eb7b204a91e28e9fad14f536",
          "amount": 0.1125,
          "rawAmount": "112502500000000000"
        }
      ],
      "feesOnTop": [
        {
          "kind": "royalty",
          "recipient": "0xaae7ac476b117bccafe2f05f582906be44bc8ff1",
          "bps": 250,
          "amount": 0.56251,
          "rawAmount": "562512500000000000"
        }
      ]
    }
  ]
}
*/

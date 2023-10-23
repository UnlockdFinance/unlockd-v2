import Axios from 'axios';
import Spinner from './spinner';
import BigNumber from 'bignumber.js';
import fs from 'fs';
import {ethers} from 'ethers';

// const URL = 'https://api-sepolia.reservoir.tools';
// const getTokens = async () => {
//   const data: APIData = {
//     items: [
//       {
//         quantity: 1,
//         token: nftToken,
//       },
//     ],
//     onlyPath: false,
//     normalizeRoyalties: true,
//     allowInactiveOrderIds: false,
//     partial: false,
//     skipBalanceCheck: true,
//     excludeEOA: true,
//     taker: taker,
//     forceRouter: true,
//     currency: currency,
//     swapProvider: 'uniswap',
//   };

//   try {
//     const result = await Axios.post('https://api.reservoir.tools/execute/sell/v7', data, {
//       headers: {
//         'x-api-key': RESERVOIR_API_KEY,
//       },
//     });

//     // Alsways we return the last element
//     return result.data;
//   } catch (error) {
//     Spinner.space();
//     console.log(error);
//     await Spinner.spinnerError();
//     await Spinner.stopSpinner();
//   }
// };

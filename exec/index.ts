require('dotenv').config();
import {Command} from 'commander';
import {exec as execReservoir} from './reservoir';
import {exec as execBitmap} from './bitmap';
import Spinner from './spinner';

const program = new Command();

program.description('Unlockd v2 Cli');
program.option('-v, --verbose', 'verbose logging');
program.version('0.0.1', '--version', 'output the current version');
program
  .command('generate')
  .description('Generate test data on current block')
  .option('--address <string>', 'Taker of the NFT on succeed')
  .option('--nft <string>', 'Address and tokenId of the nft format: "address:tokenId"')
  .option('--action <string>',' Actions "buy" or "sell" ')
  .option(
    '--currency <string>',
    'Currency address, eth is 0x0000000000000000000000000000000000000000'
  )
  .action(execReservoir);

program
  .command('bitmap')
  .description('Generate test data on current block')
  .option('--price <number>', 'Full price of the loan')
  .option('--loanId <number>', 'Id of the loan')
  .option('--threshold <number>', 'Threshold of the position in % ')
  .option('--ltv <number>', 'Ltv of the position in % ')
  .action(execBitmap);
// Start
async function main() {
  await Spinner.init();
  return program.parseAsync();
}

Spinner.space(); // log a new line so there is a nice space
main().then();

process.on('unhandledRejection', function (err: Error) {
  const debug = program.opts().verbose;
  if (debug) {
    console.error(err.stack);
  }
  Spinner.spinnerError();
  Spinner.stopSpinner();
  program.error('', {exitCode: 1});
});

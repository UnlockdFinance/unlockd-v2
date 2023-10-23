function numHex(s: number, digits: number) {
  var a = s.toString(16);
  while (a.length < digits) {
    a = '0' + a;
  }
  return a.toUpperCase();
}

// WARN: The price may experience overflow due to its value, but please note that this is solely for testing purposes.
export const exec = async (str: any) => {
  if (str.price && str.threshold && str.ltv && str.tokenId) new Error('All params are required');

  console.log(
    'Result: ',
    `0x${numHex(parseInt(str.price), 55)}${numHex(parseInt(str.threshold), 2)}${numHex(
      parseInt(str.ltv),
      2
    )}${numHex(parseInt(str.loanId), 5)}`
  );

  return;
};

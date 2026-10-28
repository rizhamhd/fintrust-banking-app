const fs = require('node:fs');
const zlib = require('node:zlib');
const kiwi = require('kiwi-schema');
const input = fs.readFileSync(process.argv[2]);
if (input.subarray(0,8).toString() !== 'fig-kiwi') throw Error('Not a Figma canvas');
const blocks = [];
for (let cursor = 12; cursor < input.length;) {
  const length = input.readUInt32LE(cursor); cursor += 4;
  const bytes = input.subarray(cursor, cursor + length); cursor += length;
  blocks.push(bytes.readUInt32LE(0) === 0xfd2fb528 ? zlib.zstdDecompressSync(bytes) : zlib.inflateRawSync(bytes));
}
const definition = kiwi.decodeBinarySchema(blocks[0]);
const decoded = kiwi.compileSchema(definition).decodeMessage(blocks[1]);
fs.writeFileSync(process.argv[3], JSON.stringify(decoded, (_, v) => v instanceof Uint8Array ? Array.from(v) : v));
console.log('Decoded nodes:', decoded.nodeChanges.length);

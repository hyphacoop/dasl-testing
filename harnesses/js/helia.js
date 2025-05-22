import * as dagcbor from "@ipld/dag-cbor";
import cbor from "cbor";

/**
 * Encode data to CBOR format
 * @param {Buffer} data - Data to encode
 * @returns {Promise<Buffer>} - Encoded data
 */
async function encode(data) {
  const decoded = cbor.decodeFirstSync(data);
  return dagcbor.encode(decoded);
}

/**
 * Decode CBOR data
 * @param {Buffer} data - CBOR data to decode
 * @returns {Promise<Buffer>} - Decoded data
 */
async function decode(data) {
  const decoded = dagcbor.decode(data);
  return dagcbor.encode(decoded);
}

/**
 * Check if data is invalid CBOR
 * @param {Buffer} data - CBOR data to check
 * @returns {Promise<[boolean, string]>} - [failed, error info]
 */
async function isInvalid(data) {
  try {
    dagcbor.decode(data);
    return [false, ""];
  } catch (err) {
    return [true, err.message];
  }
}

export { encode, decode, isInvalid };

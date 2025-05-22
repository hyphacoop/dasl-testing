import * as dagcbor from "@atcute/cbor";
import cbor from "cbor";

async function roundtrip(data) {
  const decoded = dagcbor.decode(data);
  return dagcbor.encode(decoded);
}

async function invalidDecode(data) {
  try {
    dagcbor.decode(data);
    return [false, ""];
  } catch (err) {
    return [true, err.message];
  }
}

async function invalidEncode(data) {
  const decoded = cbor.decodeFirstSync(data);
  try {
    dagcbor.encode(decoded);
    return [false, ""];
  } catch (err) {
    return [true, err.message];
  }
}

export { roundtrip, invalidDecode, invalidEncode };

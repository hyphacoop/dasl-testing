import cbrrr
import cbor2


def roundtrip(data):
    obj = cbrrr.decode_dag_cbor(data)
    return cbrrr.encode_dag_cbor(obj)


def invalid_decode(data):
    try:
        cbrrr.decode_dag_cbor(data)
        return False, ""
    except Exception as err:
        return True, str(err)


def invalid_encode(data):
    obj = cbor2.loads(data)
    try:
        cbrrr.encode_dag_cbor(obj)
        return False, ""
    except Exception as err:
        return True, str(err)

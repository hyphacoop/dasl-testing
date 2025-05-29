import libipld
import cbor2


def roundtrip(data):
    obj = libipld.decode_dag_cbor(data)
    return libipld.encode_dag_cbor(obj)


def invalid_decode(data):
    try:
        libipld.decode_dag_cbor(data)
        return False, ""
    except Exception as err:
        return True, str(err)
    except BaseException as e:
        if type(e).__name__ == "PanicException":
            return True, str(e)  # TODO: is raising this acceptable?
        raise e


def invalid_encode(data):
    obj = cbor2.loads(data)
    try:
        libipld.encode_dag_cbor(obj)
        return False, ""
    except Exception as err:
        return True, str(err)
    except BaseException as e:
        if type(e).__name__ == "PanicException":
            return True, str(e)  # TODO: is raising this acceptable?
        raise e

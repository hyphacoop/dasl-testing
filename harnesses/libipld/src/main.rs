use libipld::cbor::DagCborCodec;
use libipld::codec::Codec;
use libipld::Ipld;
use std::collections::HashMap;
use std::fs;
use std::io::Cursor;

#[derive(serde::Serialize, serde::Deserialize)]
struct TestResult {
    pass: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    output: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(serde::Deserialize)]
struct TestCase {
    #[serde(rename = "type")]
    test_type: String,
    data: String,
}

#[derive(serde::Serialize)]
struct Metadata {
    link: String,
    version: String,
}

#[derive(serde::Serialize)]
struct Results {
    metadata: Metadata,
    files: HashMap<String, Vec<TestResult>>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut results = Results {
        metadata: Metadata {
            link: "https://github.com/ipld/libipld".to_string(),
            version: get_dependency_version("libipld"),
        },
        files: HashMap::new(),
    };

    let fixtures_path = "../../fixtures/cbor/";
    let entries = fs::read_dir(fixtures_path)?;

    for entry in entries {
        let entry = entry?;
        let path = entry.path();

        if let Some(extension) = path.extension() {
            if extension == "json" {
                let content = fs::read_to_string(&path)?;
                let tests: Vec<TestCase> = serde_json::from_str(&content)?;

                if let Some(file_name) = path.file_name().and_then(|n| n.to_str()) {
                    results
                        .files
                        .insert(file_name.to_string(), run_tests(tests));
                }
            }
        }
    }

    let json_output = serde_json::to_string(&results)?;
    print!("{}", json_output);

    Ok(())
}

fn run_tests(tests: Vec<TestCase>) -> Vec<TestResult> {
    let mut results = Vec::with_capacity(tests.len());

    for test in tests {
        let test_data = match hex::decode(&test.data) {
            Ok(data) => data,
            Err(_) => panic!("failed to decode hex: {}", test.data),
        };

        let result = match test.test_type.as_str() {
            "roundtrip" => match roundtrip(&test_data) {
                Ok(output) => {
                    if test_data == output {
                        TestResult {
                            pass: true,
                            output: None,
                            error: None,
                        }
                    } else {
                        TestResult {
                            pass: false,
                            output: Some(hex::encode(output)),
                            error: None,
                        }
                    }
                }
                Err(err) => TestResult {
                    pass: false,
                    output: None,
                    error: Some(err),
                },
            },
            "invalid_in" => {
                let (failed, info) = invalid_decode(&test_data);
                if failed {
                    TestResult {
                        pass: true,
                        output: None,
                        error: Some(info),
                    }
                } else {
                    TestResult {
                        pass: false,
                        output: None,
                        error: None,
                    }
                }
            }
            "invalid_out" => {
                let (failed, info) = invalid_encode(&test_data);
                if failed {
                    TestResult {
                        pass: true,
                        output: None,
                        error: Some(info),
                    }
                } else {
                    TestResult {
                        pass: false,
                        output: None,
                        error: None,
                    }
                }
            }
            _ => panic!("unknown test type '{}'", test.test_type),
        };

        results.push(result);
    }

    results
}

fn roundtrip(b: &[u8]) -> Result<Vec<u8>, String> {
    let obj: Ipld = DagCborCodec
        .decode(b)
        .map_err(|e| format!("dag-cbor decode error: {}", e))?;

    let output = DagCborCodec
        .encode(&obj)
        .map_err(|e| format!("dag-cbor encode error: {}", e))?;

    Ok(output)
}

fn invalid_decode(b: &[u8]) -> (bool, String) {
    let result: Result<Ipld, _> = DagCborCodec.decode(b);

    match result {
        Ok(_) => (false, String::new()),
        Err(e) => (true, e.to_string()),
    }
}

fn invalid_encode(b: &[u8]) -> (bool, String) {
    let obj: ciborium::Value = ciborium::from_reader(Cursor::new(b))
        .expect("general CBOR library failed to decode test input");

    let ipld_obj = match cbor_value_to_ipld(obj) {
        Ok(obj) => obj,
        Err(e) => return (true, e),
    };
    match DagCborCodec.encode(&ipld_obj) {
        Ok(_) => (false, String::new()),
        Err(e) => (true, e.to_string()),
    }
}

fn cbor_value_to_ipld(value: ciborium::Value) -> Result<Ipld, String> {
    match value {
        ciborium::Value::Integer(i) => {
            Ok(Ipld::Integer(i.into()))
        }
        ciborium::Value::Bytes(b) => Ok(Ipld::Bytes(b)),
        ciborium::Value::Float(f) => Ok(Ipld::Float(f)),
        ciborium::Value::Text(s) => Ok(Ipld::String(s)),
        ciborium::Value::Bool(b) => Ok(Ipld::Bool(b)),
        ciborium::Value::Null => Ok(Ipld::Null),
        ciborium::Value::Array(arr) => {
            let mut ipld_list = Vec::new();
            for item in arr {
                ipld_list.push(cbor_value_to_ipld(item)?);
            }
            Ok(Ipld::List(ipld_list))
        }
        ciborium::Value::Map(map) => {
            let mut ipld_map = std::collections::BTreeMap::new();
            for (k, v) in map {
                if let ciborium::Value::Text(key) = k {
                    ipld_map.insert(key, cbor_value_to_ipld(v)?);
                }
            }
            Ok(Ipld::Map(ipld_map))
        }
        _ => Err(format!("Unsupported CBOR type: {:?}", value)),
    }
}

fn get_dependency_version(dependency: &str) -> String {
    let cargo_toml = std::fs::read_to_string("Cargo.toml")
        .unwrap_or_else(|_| panic!("Failed to read Cargo.toml"));
    
    for line in cargo_toml.lines() {
        let line = line.trim();
        if line.starts_with(&format!("{} = ", dependency)) {
            // Handle formats like: libipld = "0.16.0"
            if let Some(version_start) = line.find('"') {
                if let Some(version_end) = line.rfind('"') {
                    if version_start < version_end {
                        return line[version_start + 1..version_end].to_string();
                    }
                }
            }
        }
    }
    
    format!("unknown-{}", dependency)
}

use ciborium::Value as CborValue;

use dasl::drisl::Value;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io::Cursor;

include!(concat!(env!("OUT_DIR"), "/built.rs"));

// Test IDs to skip
const SKIPPED_TEST_IDS: &[&str] = &[
    "datetime_invalid_out",
    "bignum_invalid_out",
    "undefined_invalid_out",
];

#[derive(Serialize, Deserialize)]
struct TestResult {
    pass: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    output: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Deserialize)]
struct TestCase {
    #[serde(rename = "type")]
    test_type: String,
    data: String,
    id: Option<String>,
}

#[derive(Serialize)]
struct Metadata {
    link: String,
    version: String,
}

#[derive(Serialize)]
struct Results {
    metadata: Metadata,
    files: HashMap<String, Vec<TestResult>>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut results = Results {
        metadata: Metadata {
            link: "https://github.com/n0-computer/dasl".to_string(),
            version: get_dependency_version("dasl"),
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
        // Check if this test should be skipped based on its ID
        if let Some(ref id) = test.id {
            if SKIPPED_TEST_IDS.contains(&id.as_str()) {
                results.push(TestResult {
                    pass: None,
                    output: None,
                    error: None,
                });
                continue;
            }
        }

        let test_data = match hex::decode(&test.data) {
            Ok(data) => data,
            Err(_) => panic!("failed to decode hex: {}", test.data),
        };

        let result = match test.test_type.as_str() {
            "roundtrip" => match roundtrip(&test_data) {
                Ok(output) => {
                    if test_data == output {
                        TestResult {
                            pass: Some(true),
                            output: None,
                            error: None,
                        }
                    } else {
                        TestResult {
                            pass: Some(false),
                            output: Some(hex::encode(output)),
                            error: None,
                        }
                    }
                }
                Err(err) => TestResult {
                    pass: Some(false),
                    output: None,
                    error: Some(err),
                },
            },
            "invalid_in" => {
                let (failed, info) = invalid_decode(&test_data);
                if failed {
                    TestResult {
                        pass: Some(true),
                        output: None,
                        error: Some(info),
                    }
                } else {
                    TestResult {
                        pass: Some(false),
                        output: None,
                        error: None,
                    }
                }
            }
            "invalid_out" => {
                let (failed, info) = invalid_encode(&test_data);
                if failed {
                    TestResult {
                        pass: Some(true),
                        output: None,
                        error: Some(info),
                    }
                } else {
                    TestResult {
                        pass: Some(false),
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

// Roundtrip function: decode with dag-cbor, then encode back
fn roundtrip(b: &[u8]) -> Result<Vec<u8>, String> {
    // Decode using dag-cbor
    let cursor = Cursor::new(b);
    let obj: Value =
        dasl::drisl::from_reader(cursor).map_err(|e| format!("n0_dasl decode error: {}", e))?;

    // Encode back using dag-cbor
    let mut output = Vec::new();
    dasl::drisl::to_writer(&mut output, &obj)
        .map_err(|e| format!("n0_dasl encode error: {}", e))?;

    Ok(output)
}

// Check if CBOR data is invalid for decoding with dag-cbor
fn invalid_decode(b: &[u8]) -> (bool, String) {
    let cursor = Cursor::new(b);
    let result: Result<Value, _> = dasl::drisl::from_reader(cursor);

    match result {
        Ok(_) => (false, String::new()),
        Err(e) => (true, e.to_string()),
    }
}

// Check if CBOR data cannot be encoded with dag-cbor after decoding with general CBOR
fn invalid_encode(b: &[u8]) -> (bool, String) {
    // First decode with general CBOR library (ciborium)
    let cursor = Cursor::new(b);
    let obj: CborValue =
        ciborium::from_reader(cursor).expect("general CBOR library failed to decode test input");

    // Try to encode with dag-cbor
    let mut output = Vec::new();
    match dasl::drisl::to_writer(&mut output, &obj) {
        Ok(_) => (false, String::new()),
        Err(e) => (true, e.to_string()),
    }
}

fn get_dependency_version(dependency: &str) -> String {
    DEPENDENCIES
        .iter()
        .find(|(name, _)| name == &dependency)
        .map(|(_, version_info)| version_info.to_string())
        .unwrap_or_else(|| format!("unknown-{}", dependency))
}

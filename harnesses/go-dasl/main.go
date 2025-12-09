package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"runtime/debug"
	"slices"
	"strings"

	"github.com/fxamacker/cbor/v2"
	"github.com/hyphacoop/go-dasl/drisl"
)

// Test IDs to skip
var skippedTestIDs = []string{
	"undefined_invalid_out",
}

type testResult struct {
	Pass   *bool  `json:"pass"`
	Output string `json:"output,omitempty"`
	Error  string `json:"error,omitempty"`
}

type testCase struct {
	Type string
	Data string
	ID   string
	Tags []string
}
type metadata struct {
	Link    string `json:"link"`
	Version string `json:"version"`
}

func main() {
	results := struct {
		Metadata metadata                 `json:"metadata"`
		Files    map[string][]*testResult `json:"files"`
	}{
		Metadata: metadata{
			Link:    "https://github.com/hyphacoop/go-dasl",
			Version: getModuleVersion("github.com/hyphacoop/go-dasl"),
		},
		Files: make(map[string][]*testResult),
	}
	err := filepath.WalkDir("../../fixtures/cbor/", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}
		if !strings.HasSuffix(path, ".json") {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		var tests []*testCase
		if err := json.Unmarshal(b, &tests); err != nil {
			return err
		}
		results.Files[filepath.Base(path)] = runTests(tests)
		return nil
	})
	if err != nil {
		panic(err)
	}

	b, err := json.Marshal(&results)
	if err != nil {
		panic(err)
	}
	os.Stdout.Write(b)
}

func runTests(tests []*testCase) []*testResult {
	trueVal, falseVal := true, false
	results := make([]*testResult, len(tests))
	for i, test := range tests {
		// Check if this test should be skipped based on its ID
		if test.ID != "" && slices.Contains(skippedTestIDs, test.ID) {
			results[i] = &testResult{
				Pass: nil,
			}
			continue
		}

		testData, err := hex.DecodeString(test.Data)
		if err != nil {
			panic(fmt.Errorf("failed to decode hex: %s", test.Data))
		}

		switch test.Type {
		case "roundtrip":
			output, err := roundtrip(testData)
			if err != nil {
				results[i] = &testResult{
					Pass:  &falseVal,
					Error: err.Error(),
				}
			} else if bytes.Equal(testData, output) {
				// Encoding matches expected output
				results[i] = &testResult{Pass: &trueVal}
			} else {
				results[i] = &testResult{
					Pass:   &falseVal,
					Output: hex.EncodeToString(output),
				}
			}
		case "invalid_in":
			failed, info := invalidDecode(testData)
			if failed {
				// Failed to decode an invalid input, so the test passes
				results[i] = &testResult{
					Pass:  &trueVal,
					Error: info, // expected error
				}
			} else {
				results[i] = &testResult{
					Pass: &falseVal,
				}
			}
		case "invalid_out":
			failed, info := invalidEncode(testData)
			if failed {
				// Failed to encode invalid data, so the test passes
				results[i] = &testResult{
					Pass:  &trueVal,
					Error: info, // expected error
				}
			} else {
				results[i] = &testResult{
					Pass: &falseVal,
				}
			}
		default:
			panic(fmt.Errorf("unknown test type '%s'", test.Type))
		}
	}
	return results
}

func roundtrip(b []byte) ([]byte, error) {
	// Decode using library to test decoding ability
	var v any
	dec, err := drisl.DecOptions{
		MaxNestedLevels: 3001, // For nested test
	}.DecMode()
	if err != nil {
		panic(err)
	}
	if err := dec.Unmarshal(b, &v); err != nil {
		return nil, err
	}
	// Re-encode and return to check nothing changed
	return drisl.Marshal(v)
}

// invalidDecode returns true if the provided CBOR is invalid.
// The second return value is the error.
func invalidDecode(b []byte) (bool, string) {
	var v any
	err := drisl.Unmarshal(b, &v)
	if err == nil {
		return false, ""
	}
	return true, err.Error()
}

// invalidEncode returns true if the provided CBOR cannot be encoded
// after being decoded by a neutral decoder.
// The second return value is the error.
func invalidEncode(b []byte) (bool, string) {
	var obj any
	if err := cbor.Unmarshal(b, &obj); err != nil {
		panic(fmt.Errorf("general CBOR library failed to decode test input: %v", err))
	}
	enc, err := drisl.EncOptions{
		Time: drisl.TimeModeReject, // For datetime test
	}.EncMode()
	if err != nil {
		panic(err)
	}
	_, err = enc.Marshal(obj)
	if err == nil {
		return false, ""
	}
	return true, err.Error()
}

func getModuleVersion(path string) string {
	bi, ok := debug.ReadBuildInfo()
	if !ok {
		// Build has no debug info
		return ""
	}
	for _, dep := range bi.Deps {
		if dep.Path != path {
			continue
		}
		if dep.Replace != nil {
			// Import has been replaced
			// Assume the replace wasn't replaced also
			return dep.Replace.Version
		}
		return dep.Version
	}
	// Dep doesn't exist
	return ""
}

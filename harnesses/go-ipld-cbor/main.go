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
	"strings"

	"github.com/fxamacker/cbor/v2"
	cbornode "github.com/ipfs/go-ipld-cbor"
)

type testResult struct {
	Pass   bool   `json:"pass"`
	Output string `json:"output,omitempty"`
	Error  string `json:"error,omitempty"`
}

type testCase struct {
	Type string
	Data string
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
			Link:    "https://github.com/ipfs/go-ipld-cbor",
			Version: getModuleVersion("github.com/ipfs/go-ipld-cbor"),
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
	results := make([]*testResult, len(tests))
	for i, test := range tests {
		testData, err := hex.DecodeString(test.Data)
		if err != nil {
			panic(fmt.Errorf("failed to decode hex: %s", test.Data))
		}

		switch test.Type {
		case "roundtrip":
			output, err := roundtrip(testData)
			if err != nil {
				results[i] = &testResult{
					Pass:  false,
					Error: err.Error(),
				}
			} else if bytes.Equal(testData, output) {
				// Encoding matches expected output
				results[i] = &testResult{Pass: true}
			} else {
				results[i] = &testResult{
					Pass:   false,
					Output: hex.EncodeToString(output),
				}
			}
		case "invalid_in":
			failed, info := invalidDecode(testData)
			if failed {
				// Failed to decode an invalid input, so the test passes
				results[i] = &testResult{
					Pass:  true,
					Error: info, // expected error
				}
			} else {
				results[i] = &testResult{
					Pass: false,
				}
			}
		case "invalid_out":
			failed, info := invalidEncode(testData)
			if failed {
				// Failed to encode invalid data, so the test passes
				results[i] = &testResult{
					Pass:  true,
					Error: info, // expected error
				}
			} else {
				results[i] = &testResult{
					Pass: false,
				}
			}
		default:
			panic(fmt.Errorf("unknown test type '%s'", test.Type))
		}
	}
	return results
}

func roundtrip(b []byte) ([]byte, error) {
	var obj any
	if err := cbornode.DecodeInto(b, &obj); err != nil {
		return nil, err
	}
	return cbornode.Encode(obj)
}

// invalidDecode returns true if the provided CBOR is invalid.
// The second return value is the error.
func invalidDecode(b []byte) (bool, string) {
	var obj any
	err := cbornode.DecodeInto(b, &obj)
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
		panic("general CBOR library failed to decode test input")
	}
	_, err := cbornode.Encode(obj)
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

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

	"github.com/ipld/go-ipld-prime/codec/dagcbor"
	"github.com/ipld/go-ipld-prime/node/basicnode"
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
			Link:    "https://github.com/ipld/go-ipld-prime",
			Version: getModuleVersion("github.com/ipld/go-ipld-prime"),
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
	np := basicnode.Prototype.Any
	nb := np.NewBuilder()
	if err := dagcbor.Decode(nb, bytes.NewReader(b)); err != nil {
		return nil, err
	}
	n := nb.Build()

	// Re-encode and return to check nothing changed
	var buf bytes.Buffer
	if err := dagcbor.Encode(n, &buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// invalidDecode returns true if the provided CBOR is invalid.
// The second return value is the error.
func invalidDecode(b []byte) (bool, string) {
	np := basicnode.Prototype.Any
	nb := np.NewBuilder()
	err := dagcbor.Decode(nb, bytes.NewReader(b))
	if err == nil {
		return false, ""
	}
	return true, err.Error()
}

// invalidEncode returns true if the provided CBOR cannot be encoded
// after being decoded by a neutral decoder.
// The second return value is the error.
func invalidEncode(b []byte) (bool, string) {
	// TODO: decode using general CBOR library
	// This allows for only encoding to be tested rather than decode-strictness as well
	//
	// var data any
	// if err := cbor.Unmarshal(b, &data); err != nil {
	// 	return nil, err
	// }
	// return ipld.Marshal(dagcbor.Encode, &data, nil)

	// Currently we can't decode using a different library
	// Because ipld.Marshal requires knowing the full type/schema of whatever it's marshalling
	// It's really annoying but I guess it's to ensure it's only encoding things that already
	// conform to the IPLD schema.
	// So for now we decode with the dag-cbor decoder
	// In practice this still sort of works because the dag-cbor decoder is permissive,
	// in line with the dag-cbor spec.
	// "DAG-CBOR decoders may relax strictness requirements by default"
	// https://ipld.io/specs/codecs/dag-cbor/spec/#decode-strictness

	_, err := roundtrip(b)
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

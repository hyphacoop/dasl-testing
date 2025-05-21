package main

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"github.com/ipld/go-ipld-prime/codec/dagcbor"
	"github.com/ipld/go-ipld-prime/node/basicnode"
)

type testResult struct {
	Pass   bool   `json:"pass"`
	Output string `json:"output,omitempty"`
	Error  string `json:"error,omitempty"`
}

type testCase struct {
	Type   string
	Input  string
	Output string
	Reason string
	Tags   []string
}

func main() {
	results := make(map[string][]*testResult)
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
		results[filepath.Base(path)] = runTests(tests)
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
		var testInput []byte
		var testOutput []byte
		var err error

		if test.Input != "" {
			testInput, err = hex.DecodeString(test.Input)
			if err != nil {
				panic(fmt.Errorf("failed to decode hex: %s", test.Input))
			}
		}
		if test.Output != "" {
			testOutput, err = hex.DecodeString(test.Output)
			if err != nil {
				panic(fmt.Errorf("failed to decode hex: %s", test.Output))
			}
		}

		switch test.Type {
		case "encode":
			output, err := encode(testInput)
			if err != nil {
				results[i] = &testResult{
					Pass:  false,
					Error: err.Error(),
				}
			} else if bytes.Equal(testOutput, output) {
				// Encoding matches expected output
				results[i] = &testResult{Pass: true}
			} else {
				results[i] = &testResult{
					Pass:   false,
					Output: hex.EncodeToString(output),
				}
			}
		case "decode":
			output, err := decode(testInput)
			if err != nil {
				results[i] = &testResult{
					Pass:  false,
					Error: err.Error(),
				}
			} else if bytes.Equal(testInput, output) {
				// Decode and re-encode didn't change the input
				results[i] = &testResult{Pass: true}
			} else {
				results[i] = &testResult{
					Pass:   false,
					Output: hex.EncodeToString(output),
				}
			}
		case "invalid":
			failed, info := isInvalid(testInput)
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
		default:
			panic(fmt.Errorf("unknown test type '%s'", test.Type))
		}
	}
	return results
}

func encode(b []byte) ([]byte, error) {
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
	return decode(b)
}

func decode(b []byte) ([]byte, error) {
	// Decode using library to test decoding ability
	np := basicnode.Prototype.Any
	nb := np.NewBuilder()
	if err := dagcbor.Decode(nb, bytes.NewReader(b)); err != nil {
		return nil, err
	}
	n := nb.Build()

	// Re-encode and return to check the decoding went okay
	var buf bytes.Buffer
	if err := dagcbor.Encode(n, &buf); err != nil {
		return nil, err
	}
	return buf.Bytes(), nil
}

// isInvalid returns true if the provided CBOR is invalid.
// The second argument is the error.
func isInvalid(b []byte) (bool, string) {
	np := basicnode.Prototype.Any
	nb := np.NewBuilder()
	err := dagcbor.Decode(nb, bytes.NewReader(b))
	if err == nil {
		return false, ""
	}
	return true, err.Error()
}

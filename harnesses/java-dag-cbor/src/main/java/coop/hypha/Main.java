package coop.hypha;

import java.io.*;
import java.nio.file.*;
import java.util.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import org.peergos.cbor.*;
import com.authlete.cbor.CBORParser;

public class Main {

    // Test IDs to skip
    private static final String[] SKIPPED_TEST_IDS = {
        // Add test IDs here to skip them
    };

    public static class TestResult {
        @JsonProperty("pass")
        private Boolean pass;
        
        @JsonProperty("output")
        @JsonInclude(JsonInclude.Include.NON_NULL)
        private String output;
        
        @JsonProperty("error")
        @JsonInclude(JsonInclude.Include.NON_NULL)
        private String error;
        
        public TestResult() {}

        public TestResult(Boolean pass) {
            this.pass = pass;
        }

        public TestResult(Boolean pass, String output, String error) {
            this.pass = pass;
            this.output = output;
            this.error = error;
        }

        // Getters and setters
        public Boolean isPass() { return pass; }
        public void setPass(Boolean pass) { this.pass = pass; }
        public String getOutput() { return output; }
        public void setOutput(String output) { this.output = output; }
        public String getError() { return error; }
        public void setError(String error) { this.error = error; }
    }
    
    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class TestCase {
        @JsonProperty("type")
        private String type;

        @JsonProperty("data")
        private String data;

        @JsonProperty("id")
        private String id;

        @JsonProperty("tags")
        private List<String> tags;

        public TestCase() {}

        // Getters and setters
        public String getType() { return type; }
        public void setType(String type) { this.type = type; }
        public String getData() { return data; }
        public void setData(String data) { this.data = data; }
        public String getId() { return id; }
        public void setId(String id) { this.id = id; }
        public List<String> getTags() { return tags; }
        public void setTags(List<String> tags) { this.tags = tags; }
    }
    
    public static class Metadata {
        @JsonProperty("link")
        private String link;
        
        @JsonProperty("version")
        private String version;
        
        public Metadata() {}
        
        public Metadata(String link, String version) {
            this.link = link;
            this.version = version;
        }
        
        // Getters and setters
        public String getLink() { return link; }
        public void setLink(String link) { this.link = link; }
        public String getVersion() { return version; }
        public void setVersion(String version) { this.version = version; }
    }
    
    public static class Results {
        @JsonProperty("metadata")
        private Metadata metadata;
        
        @JsonProperty("files")
        private Map<String, List<TestResult>> files;
        
        public Results() {
            this.files = new HashMap<>();
        }
        
        // Getters and setters
        public Metadata getMetadata() { return metadata; }
        public void setMetadata(Metadata metadata) { this.metadata = metadata; }
        public Map<String, List<TestResult>> getFiles() { return files; }
        public void setFiles(Map<String, List<TestResult>> files) { this.files = files; }
    }
    
    public static void main(String[] args) {
        Results results = new Results();
        results.setMetadata(new Metadata(
            "https://github.com/Peergos/dag-cbor",
            getDagCborVersion()
        ));
        
        try {
            Path fixturesPath = Paths.get("../../fixtures/cbor/");
            Files.walk(fixturesPath)
                .filter(path -> path.toString().endsWith(".json"))
                .forEach(path -> {
                    try {
                        byte[] fileBytes = Files.readAllBytes(path);
                        String content = new String(fileBytes);
                        
                        ObjectMapper mapper = new ObjectMapper();
                        TestCase[] tests = mapper.readValue(content, TestCase[].class);
                        
                        String fileName = path.getFileName().toString();
                        results.getFiles().put(fileName, runTests(Arrays.asList(tests)));
                    } catch (IOException e) {
                        throw new RuntimeException(e);
                    }
                });
            
            ObjectMapper mapper = new ObjectMapper();
            String jsonOutput = mapper.writeValueAsString(results);
            System.out.print(jsonOutput);
            
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }
    
    private static List<TestResult> runTests(List<TestCase> tests) {
        List<TestResult> results = new ArrayList<>(tests.size());

        testLoop: for (TestCase test : tests) {
            // Check if this test should be skipped based on its ID
            if (test.getId() != null && !test.getId().isEmpty()) {
                for (String skipID : SKIPPED_TEST_IDS) {
                    if (test.getId().equals(skipID)) {
                        results.add(new TestResult(null));
                        continue testLoop;
                    }
                }
            }

            byte[] testData;
            try {
                testData = HexFormat.of().parseHex(test.getData());
            } catch (Exception e) {
                throw new RuntimeException("Failed to decode hex: " + test.getData(), e);
            }

            switch (test.getType()) {
                case "roundtrip":
                    try {
                        byte[] output = roundtrip(testData);
                        if (Arrays.equals(testData, output)) {
                            // Encoding matches expected output
                            results.add(new TestResult(true));
                        } else {
                            results.add(new TestResult(false, bytesToHex(output), null));
                        }
                    } catch (Exception e) {
                        results.add(new TestResult(false, null, e.toString()));
                    }
                    break;
                    
                case "invalid_in":
                    InvalidResult invalidDecodeResult = invalidDecode(testData);
                    if (invalidDecodeResult.failed) {
                        // Failed to decode an invalid input, so the test passes
                        results.add(new TestResult(true, null, invalidDecodeResult.info));
                    } else {
                        if (invalidDecodeResult.info.length() > 0) {
                            results.add(new TestResult(false, null, invalidDecodeResult.info));
                        } else {
                            results.add(new TestResult(false));
                        }
                    }
                    break;
                    
                case "invalid_out":
                    InvalidResult invalidEncodeResult = invalidEncode(testData);
                    if (invalidEncodeResult.failed) {
                        // Failed to encode invalid data, so the test passes
                        results.add(new TestResult(true, null, invalidEncodeResult.info));
                    } else {
                        if (invalidEncodeResult != null && invalidEncodeResult.info.length() > 0) {
                            results.add(new TestResult(false, null, invalidEncodeResult.info));
                        } else {
                            results.add(new TestResult(false));
                        }
                    }
                    break;
                    
                default:
                    throw new RuntimeException("Unknown test type '" + test.getType() + "'");
            }
        }
        
        return results;
    }
    
    private static class InvalidResult {
        boolean failed;
        String info;
        
        InvalidResult(boolean failed, String info) {
            this.failed = failed;
            this.info = info;
        }
    }
    
    private static byte[] roundtrip(byte[] data) throws Exception {
        CborObject obj = CborObject.fromByteArray(data);
        return dagCborEncode(obj).serialize();
    }
    
    private static InvalidResult invalidDecode(byte[] data) {
        try {
            CborObject.fromByteArray(data);
            return new InvalidResult(false, "");
        } catch (Exception e) {
            return new InvalidResult(true, e.toString());
        }
    }
    
    private static InvalidResult invalidEncode(byte[] data) {
        try {
            Object obj = new CBORParser(data).next();
            dagCborEncode(obj);
            return new InvalidResult(false, "");
        } catch (Exception e) {
            return new InvalidResult(true, e.toString());
        }
    }
    
    // My own generic encoder because it's not available
    // https://github.com/Peergos/dag-cbor/issues/1
    private static Cborable dagCborEncode(Object obj) {
        if (obj instanceof Cborable) {
            return ((Cborable)obj);
        } else if (obj == null) {
            return new CborObject.CborNull();
        // } else if (obj instanceof String) {
        //     return new CborObject.CborString((String)obj);
        } else if (obj instanceof Float || obj instanceof Double) {
            return new CborObject.CborDouble(((Number) obj).doubleValue());
        } else if (obj instanceof Integer || obj instanceof Long || obj instanceof Short || obj instanceof Byte) {
            return new CborObject.CborLong(((Number) obj).longValue());
        // } else if (obj instanceof Boolean) {
        //     return new CborObject.CborBoolean(Boolean.TRUE.equals((Boolean)obj));
        } else if (obj instanceof Map) {
            Map<String, Object> map = (Map<String, Object>) obj;
            SortedMap<String, Cborable> state = new TreeMap<>(); // TODO: try HashMap also
            for (var entry : map.entrySet()) {
                state.put(entry.getKey(), dagCborEncode(entry.getValue()));
            }
            return CborObject.CborMap.build(state);
        // } else if (obj instanceof List) {
        //     return CborObject.CborList.build((List<Object>) obj, x -> dagCborEncode(x));
        }
        throw new UnsupportedOperationException("harness: unknown type:"+obj);
    }

    private static String getDagCborVersion() {
        String pomPath = "META-INF/maven/com.github.peergos/dag-cbor/pom.properties";
        try (InputStream is = org.peergos.cbor.CborType.class.getClassLoader().getResourceAsStream(pomPath)) {
            if (is != null) {
                Properties props = new Properties();
                props.load(is);
                return props.getProperty("version");
            } else {
                return "pom.properties not found";
            }
        } catch (IOException e) {
            return "Error reading pom.properties: " + e.getMessage();
        }
    }

    private static String bytesToHex(byte[] bytes) {
        StringBuilder result = new StringBuilder();
        for (byte b : bytes) {
            result.append(String.format("%02x", b));
        }
        return result.toString();
    }
}

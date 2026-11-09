/**
 * @description Service class responsible for generating compliant 24-character Commonwealth
 *              RFID tracking tags for Product Packages across the seed-to-sale supply chain.
 *              State RFID tags follow the standard format:
 *              - 12-character State/Facility Prefix: "1A4000312678"
 *              - 12-character Unique Hexadecimal Suffix (uppercase 0-9, A-F)
 */
public with sharing class RFIDGeneratorService {

    public static final String STATE_PREFIX = '1A4000312678';
    private static final Integer HEX_SUFFIX_LENGTH = 12;

    /**
     * @description Generates a single compliant 24-character RFID tag.
     * @return 24-character unique RFID tracking tag.
     */
    public static String generateTag() {
        List<String> tags = generateTags(1);
        return (tags != null && !tags.isEmpty()) ? tags[0] : null;
    }

    /**
     * @description Generates a bulk collection of unique compliant 24-character RFID tags.
     *              Adheres to strict bulkification and guarantees uniqueness within the batch.
     * @param count Number of unique tags to generate.
     * @return List of unique 24-character RFID tracking tag strings.
     */
    public static List<String> generateTags(Integer count) {
        if (count == null || count <= 0) {
            return new List<String>();
        }

        Set<String> uniqueTags = new Set<String>();

        while (uniqueTags.size() < count) {
            // Generate 128-bit cryptographically strong pseudo-random key (16 bytes = 32 hex chars)
            Blob randomBytes = Crypto.generateAesKey(128);
            String hexString = EncodingUtil.convertToHex(randomBytes).toUpperCase();
            String candidateTag = STATE_PREFIX + hexString.substring(0, HEX_SUFFIX_LENGTH);
            uniqueTags.add(candidateTag);
        }

        return new List<String>(uniqueTags);
    }
}

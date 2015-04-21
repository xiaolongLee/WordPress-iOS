#import "DisplayableImageHelper.h"

static const NSInteger FeaturedImageMinimumWidth = 640;

@implementation DisplayableImageHelper

/**
 Get the url path of the image to display for a post.

 @param dict A dictionary representing a posts attachments from the REST API.
 @return The url path for the featured image or nil
 */
+ (NSString *)searchPostAttachmentsForImageToDisplay:(NSDictionary *)attachmentsDict
{
    NSArray *attachments = [[attachmentsDict dictionaryForKey:@"attachments"] allValues];
    if ([attachments count] == 0) {
        return nil;
    }

    NSString *imageToDisplay;

    attachments = [self sanitizeAttachmentsArray:attachments];
    NSSortDescriptor *descriptor = [[NSSortDescriptor alloc] initWithKey:@"width" ascending:NO];
    attachments = [attachments sortedArrayUsingDescriptors:@[descriptor]];
    NSDictionary *attachment = [attachments firstObject];
    NSString *mimeType = [attachment stringForKey:@"mime_type"];
    NSInteger width = [[attachment numberForKey:@"width"] integerValue];
    if ([mimeType rangeOfString:@"image"].location != NSNotFound && width >= FeaturedImageMinimumWidth) {
        imageToDisplay = [attachment stringForKey:@"URL"];
    }

    return imageToDisplay;
}

/**
 Loops over the passed attachments array. For each attachment dictionary
 the value of the `width` key is ensured to be an NSNumber. If the value
 was an empty string the NSNumber zero is substituted.
 */
+ (NSArray *)sanitizeAttachmentsArray:(NSArray *)attachments
{
    NSMutableArray *marr = [NSMutableArray array];
    NSString *key = @"width";
    for (NSDictionary *attachment in attachments) {
        NSMutableDictionary *mdict = [attachment mutableCopy];
        NSNumber *numVal = [attachment numberForKey:key];
        if (!numVal) {
            numVal = @0;
        }
        [mdict setObject:numVal forKey:key];
        [marr addObject:mdict];
    }
    return [marr copy];
}

/**
 Search the passed string for an image that is a good candidate to feature.

 @param content The content string to search.
 @return The url path for the image or an empty string.
 */
+ (NSString *)searchPostContentForImageToDisplay:(NSString *)content
{
    NSString *imageSrc = @"";
    // If there is no image tag in the content, just bail.
    if (!content || [content rangeOfString:@"<img"].location == NSNotFound) {
        return imageSrc;
    }

    // Get all the things
    static NSRegularExpression *imgRegex;
    static NSRegularExpression *srcRegex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error;
        imgRegex = [NSRegularExpression regularExpressionWithPattern:@"<img(\\s+.*?)(?:src\\s*=\\s*(?:'|\")(.*?)(?:'|\"))(.*?)>" options:NSRegularExpressionCaseInsensitive error:&error];
        srcRegex = [NSRegularExpression regularExpressionWithPattern:@"src\\s*=\\s*(?:'|\")(.*?)(?:'|\")" options:NSRegularExpressionCaseInsensitive error:&error];
    });

    NSArray *matches = [imgRegex matchesInString:content options:NSRegularExpressionCaseInsensitive range:NSMakeRange(0, [content length])];

    NSInteger currentMaxWidth = FeaturedImageMinimumWidth;
    for (NSTextCheckingResult *match in matches) {
        NSString *tag = [content substringWithRange:match.range];
        // Get the source
        NSRange srcRng = [srcRegex rangeOfFirstMatchInString:tag options:NSRegularExpressionCaseInsensitive range:NSMakeRange(0, [tag length])];
        NSString *src = [tag substringWithRange:srcRng];
        NSCharacterSet *charSet = [NSCharacterSet characterSetWithCharactersInString:@"\"'="];
        NSRange quoteRng = [src rangeOfCharacterFromSet:charSet];
        src = [src substringFromIndex:quoteRng.location];
        src = [src stringByTrimmingCharactersInSet:charSet];

        // Check the tag for a good width
        NSInteger width = MAX([self widthFromElementAttribute:tag], [self widthFromQueryString:src]);
        if (width > currentMaxWidth) {
            imageSrc = src;
            currentMaxWidth = width;
        }
    }

    return imageSrc;
}

/**
 Search the passed string for an image that is a good candidate to feature.
 @param content The content string to search.
 @return The url path for the image or an empty string.
 */
+ (NSString *)searchContentBySizeClassForImageToFeature:(NSString *)content
{
    NSString *str = @"";
    // If there is no image tag in the content, just bail.
    if (!content || [content rangeOfString:@"<img"].location == NSNotFound) {
        return str;
    }
    // If there is not a large or full sized image, just bail.
    NSString *className = @"size-full";
    NSRange range = [content rangeOfString:className];
    if (range.location == NSNotFound) {
        className = @"size-large";
        range = [content rangeOfString:className];
        if (range.location == NSNotFound) {
            className = @"size-medium";
            range = [content rangeOfString:className];
            if (range.location == NSNotFound) {
                return str;
            }
        }
    }
    // find the start of the image
    range = [content rangeOfString:@"<img" options:NSBackwardsSearch | NSCaseInsensitiveSearch range:NSMakeRange(0, range.location)];
    if (range.location == NSNotFound) {
        return str;
    }
    // Build the regex once and keep it around for subsequent calls.
    static NSRegularExpression *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error;
        regex = [NSRegularExpression regularExpressionWithPattern:@"src=\"\\S+\"" options:NSRegularExpressionCaseInsensitive error:&error];
    });
    NSInteger length = [content length] - range.location;
    range = [regex rangeOfFirstMatchInString:content options:NSRegularExpressionCaseInsensitive range:NSMakeRange(range.location, length)];
    if (range.location == NSNotFound) {
        return str;
    }
    range = NSMakeRange(range.location+5, range.length-6);
    str = [content substringWithRange:range];
    str = [[str componentsSeparatedByString:@"?"] objectAtIndex:0];
    return str;
}

+ (NSInteger)widthFromElementAttribute:(NSString *)tag
{
    NSRange rng = [tag rangeOfString:@"width=\""];
    if (rng.location == NSNotFound) {
        return 0;
    }
    NSInteger startingIdx = rng.location + rng.length;
    rng = [tag rangeOfString:@"\"" options:NSCaseInsensitiveSearch range:NSMakeRange(startingIdx, [tag length] - startingIdx)];
    if (rng.location == NSNotFound) {
        return 0;
    }

    NSString *widthStr = [tag substringWithRange:NSMakeRange(startingIdx, [tag length] - rng.location)];
    return [widthStr integerValue];
}

+ (NSInteger)widthFromQueryString:(NSString *)src
{
    NSURL *url = [NSURL URLWithString:src];
    NSString *query = [url query];
    NSRange rng = [query rangeOfString:@"w="];
    if (rng.location == NSNotFound) {
        return 0;
    }

    NSString *str = [query substringFromIndex:rng.location + rng.length];
    NSString *widthStr = [[str componentsSeparatedByString:@"&"] firstObject];

    return [widthStr integerValue];
}

@end

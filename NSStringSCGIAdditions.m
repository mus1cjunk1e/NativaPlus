/******************************************************************************
 * Nativa - MacOS X UI for rtorrent
 * http://www.aramzamzam.net
 *
 * Copyright Solomenchuk V. 2010.
 * Solomenchuk Vladimir <vovasty@aramzamzam.net>
 *
 * Licensed under the GPL, Version 3.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.gnu.org/licenses/gpl-3.0.html
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *****************************************************************************/

#import "NSStringSCGIAdditions.h"
NSString* const CONTENT_LENGTH = @"CONTENT_LENGTH";
NSString* const SCGI = @"SCGI";
NSString* const ONE = @"1";
char const zero[1] = {'\0'};
char const comma[1] = {','};

@implementation NSString (NSStringSCGIAdditions)
- (NSData *) encodeSCGI
{
    NSString *selfLength = [NSString stringWithFormat:@"%d", [self length]];
    
    int headerLength = 23+[selfLength length]; //23 = 14(CONTENT_LENGTH)+4(\0)+4(SCGI)+1(1)
    
    NSMutableData *result=[NSMutableData data];
    
    [result appendData:[[NSString stringWithFormat:@"%d:", headerLength] dataUsingEncoding: NSASCIIStringEncoding]];
    [result appendData:[CONTENT_LENGTH dataUsingEncoding: NSASCIIStringEncoding]];
    [result appendBytes:zero length:1]; // \0
    [result appendData:[selfLength dataUsingEncoding: NSASCIIStringEncoding]];
    [result appendBytes:zero length:1]; // \0
    [result appendData:[SCGI dataUsingEncoding: NSASCIIStringEncoding]];
    [result appendBytes:zero length:1]; // \0
    [result appendData:[ONE dataUsingEncoding: NSASCIIStringEncoding]];
    [result appendBytes:zero length:1]; // \0
    [result appendBytes:comma length:1]; // ,
    [result appendData:[self dataUsingEncoding: NSUTF8StringEncoding]];

	return result;
}
@end
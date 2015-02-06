/*
   Copyright 2008-2014 Fabrizio Montesi <famontesi@gmail.com>

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

include "console.iol"
include "file.iol"
include "string_utils.iol"
include "protocols/http.iol"

include "config.iol"

execution { concurrent }

interface HTTPInterface {
RequestResponse:
	default(DefaultOperationHttpRequest)(undefined)
}

inputPort HTTPInput {
Protocol: http {
	.keepAlive = true; // Keep connections open
	.debug = DebugHttp; 
	.debug.showContent = DebugHttpContent;
	.format -> format;
	.contentType -> mime;
	.statusCode -> statusCode;

	.default = "default"
}
Location: Location_Leonardo
Interfaces: HTTPInterface
}

init
{
	if ( is_defined( args[0] ) ) {
		documentRootDirectory = args[0]
	} else {
		documentRootDirectory = RootContentDirectory
	}
}

main
{
	[ default( request )( response ) {
		scope( s ) {
			install( FileNotFound => println@Console( "File not found: " + file.filename )(); statusCode = 404 );

			s = request.operation;
			s.regex = "\\?";
			split@StringUtils( s )( s );
			
			// Default page
                        shouldAddIndex = false;
                        if ( s.result[0] == "" ) {
                                shouldAddIndex = true
                        } else {
                                e = s.result[0];
                                e.suffix = "/";
                                endsWith@StringUtils( e )( shouldAddIndex )
                        };
                        if ( shouldAddIndex ) {
                                s.result[0] += DefaultPage
                        };
			
			file.filename = documentRootDirectory + s.result[0];

			getMimeType@File( file.filename )( mime );
			mime.regex = "/";
			split@StringUtils( mime )( s );
			if ( s.result[0] == "text" ) {
				file.format = "text";
				format = "html"
			} else {
				file.format = format = "binary"
			};

			readFile@File( file )( response )
		}
	} ] { nullProcess }
}

/*
   Copyright 2008-2018 Fabrizio Montesi <famontesi@gmail.com>

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
include "hooks.iol"

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
	.cacheControl.maxAge -> cacheMaxAge;

	.default = "default"
}
Location: Location_Leonardo
Interfaces: HTTPInterface
}

define setCacheHeaders
{
	shouldCache = false;
	if ( s.result[0] == "image" ) {
		shouldCache = true
	} else {
		e = file.filename;
		e.suffix = ".js";
		endsWith@StringUtils( e )( shouldCache );
		if ( !shouldCache ) {
			e.suffix = ".css";
			endsWith@StringUtils( e )( shouldCache );
			if ( !shouldCache ) {
					e.suffix = ".woff";
					endsWith@StringUtils( e )( shouldCache )
			}
		}
	};

	if ( shouldCache ) {
		cacheMaxAge = 60 * 60 * 2 // 2 hours
	}
}

define checkForMaliciousPath
{
	for( maliciousSubstring in maliciousSubstrings ) {
		contains@StringUtils( s.result[0] { .substring = maliciousSubstring } )( b );
		if ( b ) { throw( FileNotFound ) }
	}
}

init
{
	maliciousSubstrings[0] = "..";
	maliciousSubstrings[1] = ".svn";

	if ( is_defined( args[0] ) ) {
		config.wwwDirectory = args[0]
	} else {
		config.wwwDirectory = RootContentDirectory
	};
	format = "html";
	println@Console( "Leonardo started at " + global.inputPorts.HTTPInput.location )()
}

main
{
	[ default( request )( response ) {
		scope( s ) {
			install( FileNotFound => println@Console( "File not found: " + file.filename )(); statusCode = 404 );

			split@StringUtils( request.operation { .regex = "\\?" } )( s );
			query = s.result[1];

			// Default page
			shouldAddIndex = false;
      if ( s.result[0] == "" ) {
        shouldAddIndex = true
      } else {
        endsWith@StringUtils( s.result[0] { .suffix = "/" } )( shouldAddIndex )
      };
      if ( shouldAddIndex ) {
        s.result[0] += DefaultPage
      };

			checkForMaliciousPath;

			file.filename = config.wwwDirectory + s.result[0];

			getMimeType@File( file.filename )( mime );
			split@StringUtils( mime { .regex = "/" } )( s );
			if ( s.result[0] == "text" ) {
				file.format = "text";
				format = "html"
			} else {
				file.format = format = "binary"
			};

			setCacheHeaders;

			readFile@File( file )( response );

			install( PreResponseFault => response = s.PreResponseFault.response; statusCode = s.PreResponseFault.statusCode );
			with( decoratedResponse ) {
				.config -> config;
				.request.path -> s.result[0];
				.request.query -> query;
				.content -> response
			};
			run@PreResponseHook( decoratedResponse )( response )
		}
	} ] {
		run@PostResponseHook( decoratedResponse )()
	}
}

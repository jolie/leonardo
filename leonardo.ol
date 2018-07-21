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
include "types/Binding.iol"
include "runtime.iol"

include "config.iol"
include "types/PreResponseHookIface.iol"
include "types/PostResponseHookIface.iol"
include "types/LeonardoAdminIface.iol"

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

outputPort PreResponseHook {
Interfaces: PreResponseHookIface
}

outputPort PostResponseHook {
Interfaces: PostResponseHookIface
}

inputPort Admin {
Location: "local"
Interfaces: LeonardoAdminIface
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

define loadHooks
{
	if ( is_defined( config.PreResponseHook ) ) {
		PreResponseHook << config.PreResponseHook
	} else {
		loadEmbeddedService@Runtime( {
			.filepath = "hooks/pre_response.ol",
			.type = "Jolie"
		} )( PreResponseHook.location )
	};
	if ( is_defined( config.PostResponseHook ) ) {
		PostResponseHook << config.PostResponseHook
	} else {
		loadEmbeddedService@Runtime( {
			.filepath = "hooks/post_response.ol",
			.type = "Jolie"
		} )( PostResponseHook.location )
	}
}

init
{
	maliciousSubstrings[0] = "..";
	maliciousSubstrings[1] = ".svn";
	maliciousSubstrings[2] = ".git"
}

init
{
	getenv@Runtime( "LEONARDO_WWW" )( config.wwwDir );
	if ( is_defined( args[0] ) ) {
		config.wwwDir = args[0]
	};

	if ( !is_defined( config.wwwDir ) || config.wwwDir instanceof void ) {
		config.wwwDir = RootContentDirectory
	};
	if ( !Standalone ) {
		config( config )()
	};
	loadHooks;
	undef( config.PreResponseHook );
	undef( config.PostResponseHook );

	toAbsolutePath@File( config.wwwDir )( config.wwwDir );
	getFileSeparator@File()( fs );
	config.wwwDir += fs;

	getServiceDirectory@File()( dir );
	setMimeTypeFile@File( dir + fs + "META-INF" + fs + "mime.types" )();
	undef( dir ); undef( fs );

	format = "html";
	println@Console( "Leonardo started\n\tLocation: " + global.inputPorts.HTTPInput.location + "\n\tWeb directory: " + config.wwwDir )()
}

main
{
	[ default( request )( response ) {
		runPostResponseHook = false;
		scope( s ) {
			install( FileNotFound =>
				println@Console( "File not found: " + file.filename )();
				statusCode = 404
			);

			split@StringUtils( request.operation { .regex = "\\?" } )( s );

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

			requestPath = s.result[0];

			file.filename = config.wwwDir + requestPath;

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

			runPostResponseHook = true;

			install( PreResponseFault =>
				response = s.PreResponseFault.response;
				statusCode = s.PreResponseFault.statusCode;
				runPostResponseHook = false
			);
			with( decoratedResponse ) {
				.config -> config;
				.request.path = requestPath;
				if ( file.format == "text" ) {
					.content -> response
				}
			};
			run@PreResponseHook( decoratedResponse )( newResponse );
			if ( !(newResponse instanceof void) ) {
				response -> newResponse
			}
		}
	} ] {
		if ( runPostResponseHook ) {
			run@PostResponseHook( decoratedResponse )()
		}
	}
}

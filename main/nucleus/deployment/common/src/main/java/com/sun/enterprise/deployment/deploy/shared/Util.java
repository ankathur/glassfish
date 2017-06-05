/*
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
 *
 * Copyright (c) 2008-2017 Oracle and/or its affiliates. All rights reserved.
 *
 * The contents of this file are subject to the terms of either the GNU
 * General Public License Version 2 only ("GPL") or the Common Development
 * and Distribution License("CDDL") (collectively, the "License").  You
 * may not use this file except in compliance with the License.  You can
 * obtain a copy of the License at
 * https://oss.oracle.com/licenses/CDDL+GPL-1.1
 * or LICENSE.txt.  See the License for the specific
 * language governing permissions and limitations under the License.
 *
 * When distributing the software, include this License Header Notice in each
 * file and include the License file at LICENSE.txt.
 *
 * GPL Classpath Exception:
 * Oracle designates this particular file as subject to the "Classpath"
 * exception as provided by Oracle in the GPL Version 2 section of the License
 * file that accompanied this code.
 *
 * Modifications:
 * If applicable, add the following below the License Header, with the fields
 * enclosed by brackets [] replaced by your own identifying information:
 * "Portions Copyright [year] [name of copyright owner]"
 *
 * Contributor(s):
 * If you wish your version of this file to be governed by only the CDDL or
 * only the GPL Version 2, indicate your decision by adding "[Contributor]
 * elects to include this software in this distribution under the [CDDL or GPL
 * Version 2] license."  If you don't indicate a single choice of license, a
 * recipient has the option to distribute your version of this file under
 * either the CDDL, the GPL Version 2 or to extend the choice of license to
 * its licensees as provided above.  However, if you add GPL Version 2 code
 * and therefore, elected the GPL Version 2 license, then the option applies
 * only if the new code is made subject to such option by the copyright
 * holder.
 */

package com.sun.enterprise.deployment.deploy.shared;

import java.net.URI;
import java.net.URL;
import java.net.URISyntaxException;

/**
 * Utility logic.
 * 
 */
public class Util {

    private static final String SPACE = " ";  

    private static final String ENCODED_SPACE = "%20";  

   /**
    * Returns the name portion of the specified URI.  This is defined as the 
    * part of the URI's path after the final slash (if any).  If the URI ends
    * with a slash that final slash is ignored in finding the name.
    * 
    * @param uri the URI from which to extract the name
    * @return the name portion of the URI
    */
    public static String getURIName(URI uri) {
        String name = null;
        String path = uri.getSchemeSpecificPart();
        if (path != null) {
            /*
             * Strip the path up to and including the last slash, if there is one.
             * A directory URI may end in a slash, so be sure to remove it if it
             * is there.
             */
            if (path.endsWith("/")) {
                path = path.substring(0, path.length() - 1);
            }
            int startOfName = path.lastIndexOf('/') + 1; // correct whether a / appears or not
            name = path.substring(startOfName);
        }
        return name;
    }

   /**
    * Returns URI for the specified URL.  This method will take care of 
    * the space in URL.
    * 
    * @param url the URL to convert to URI
    * @return the URI
    */
    public static URI toURI(URL url) throws URISyntaxException { 
        return new URI(url.toString().replaceAll(SPACE, ENCODED_SPACE));
    }

   /**
    * Constructs a new URI by parsing the given string and then resolving it
    * against the base URI.  This method will take care of the space in String.
    *
    * @param baseUri the base URI to resolve against
    * @param uriString the String to construct URI and resolve 
    * @return the resulting URI
    */
    public static URI resolve(URI baseUri, String uriString) {
        return baseUri.resolve(uriString.replaceAll(SPACE, ENCODED_SPACE));
    }
}

/*
 * DO NOT ALTER OR REMOVE COPYRIGHT NOTICES OR THIS HEADER.
 *
 * Copyright (c) 2012-2017 Oracle and/or its affiliates. All rights reserved.
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

package org.glassfish.security.services.impl.common;


import java.util.Arrays;
import java.util.Iterator;
import java.util.TreeSet;
import java.util.Set;

import org.glassfish.security.services.api.common.Attribute;


public class AttributeImpl implements Attribute {

	private String name = null;
	private Set<String> values = new TreeSet<String>();
	
	protected AttributeImpl() {}
	
	public AttributeImpl(String name) {
		this.name = name;
	}
	
	public AttributeImpl(String name, String value) {
		this(name);
		addValue(value);
	}
	
	public AttributeImpl(String name, Set<String> values) {
		this(name);
		addValues(values);
	}
	
	public AttributeImpl(String name, String[] values) {
		this(name);
		addValues(values);
	}

	public int getValueCount() { return values.size(); }

	public String getName() { return name; }

	public String getValue() {
		if(getValueCount() == 0) {
			return null;
		}
		Iterator<String> i = values.iterator();
		return i.next();
	}

	public Set<String> getValues() { return values; }

	public String[] getValuesAsArray() { return values.toArray(new String[0]); }
	
	public void addValue(String value) {
		if (value != null && !value.trim().equals("")) {
			values.add(value);
		}
	}
	
	public void addValues(Set<String> values) {
		addValues(values.toArray(new String[0]));
	}
	
	public void addValues(String[] values) {
		for (int i = 0; i < values.length; i++) {
			addValue(values[i]);
		}
	}
	
	public void removeValue(String value) {
		values.remove(value);
	}
	
	public void removeValues(Set<String> values) {
		this.values.removeAll(values);
	}
	
	public void removeValues(String[] values) {
		this.values.removeAll(Arrays.asList(values));
	}
	
	public void clear() {
		values.clear();
	}
	
}

package gov.va.shamu.classloaders;

import java.io.File;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.net.URL;
import java.net.URLClassLoader;
import java.net.URLStreamHandlerFactory;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.HashSet;
import java.util.Iterator;
import java.util.List;
import java.util.Set;

public class ChildFirstURLClassLoader extends URLClassLoader {

	private ClassLoader system = getSystemClassLoader();
	private Set<String> requestedResources = new HashSet<String>();
	private String prepend;


	public ChildFirstURLClassLoader(URL[] classpath, ClassLoader parent) {
		super(classpath, parent);
	}

	public ChildFirstURLClassLoader(URL[] urls) {
		super(urls);
	}

	public ChildFirstURLClassLoader(URL[] urls, ClassLoader parent,
			URLStreamHandlerFactory factory) {

		super(urls, parent, factory);
	}

	@Override
	protected synchronized Class<?> loadClass(String name, boolean resolve)
			throws ClassNotFoundException {
		// First, check if the class has already been loaded
		Class<?> c = findLoadedClass(name);
		if (c == null) {
			if (c == null) {
				try {
					// checking local
					c = findClass(name);
				} catch (ClassNotFoundException e) {
					// checking parent
					// This call to loadClass may eventually call findClass
					// again, in case the parent doesn't find anything.
					c = super.loadClass(name, resolve);
				}
			}
			if (c == null) {
				if (system != null) {
					try {
						// checking system: jvm classes, endorsed, cmd
						// classpath,
						// etc.
						c = system.loadClass(name);
					} catch (ClassNotFoundException ignored) {
					}
				}
			}
		}
		if (resolve) {
			resolveClass(c);
		}
		return c;
	}

	@Override
	public URL getResource(String name) {
		URL url = null;
		if (url == null) {
			url = findResource(name);
			if (url == null) {
				// This call to getResource may eventually call findResource
				// again, in case the parent doesn't find anything.
				url = super.getResource(name);
			}
		}
		if ((url == null) && (system != null)) {
			url = system.getResource(name);
		}
		return url;
	}
	
	public String[] getRequestedResources() {
		return requestedResources.toArray(new String[requestedResources.size()]);
	}

	@Override
	public Enumeration<URL> getResources(String name) throws IOException {
		requestedResources.add(name);
		/**
		 * Similar to super, but local resources are enumerated before parent
		 * resources
		 */
		Enumeration<URL> systemUrls = null;
		if (system != null) {
			systemUrls = system.getResources(name);
		}
		Enumeration<URL> localUrls = findResources(name);
		Enumeration<URL> parentUrls = null;
		if (getParent() != null) { 
			parentUrls = getParent().getResources(name);
		} 
		final List<URL> urls = new ArrayList<URL>();

		if (localUrls != null) {
			while (localUrls.hasMoreElements()) {
				urls.add(localUrls.nextElement());
			}
		}
		if (parentUrls != null) {
			while (parentUrls.hasMoreElements()) {
				urls.add(parentUrls.nextElement());
			}
		}
		if (systemUrls != null) {
			while (systemUrls.hasMoreElements()) {
				urls.add(systemUrls.nextElement());
			}
		}
		return new Enumeration<URL>() {
			Iterator<URL> iter = urls.iterator();

			public boolean hasMoreElements() {
				return iter.hasNext();
			}

			public URL nextElement() {
				return iter.next();
			}
		};
	}
	
   public void setCurrentWorkingDirectory(String cwd) {
	   //System.out.println("Setting the current working directory to " + cwd);
	   System.getProperties().put("user.dir", cwd);
   }
	
	public void addURL(String location) {
		try {
			addURL((new File(location)).toURI().toURL());
		} catch (MalformedURLException e) {
			throw new RuntimeException(e);
		}
	}
	
	@Override
	public InputStream getResourceAsStream(String name) {
		System.out.println("Asked to get the following stream: " + name);
		InputStream stream = super.getResourceAsStream(name);
		if (stream != null)
			return stream;
		System.out.println("Asked to get the following stream: " + name);
		System.out.println("Resorting to Files....");
		File f = findFile(name);
		if (f == null) {
			System.out.println("File does not exist!");
			return null;
		}
		System.out.println("File does exist!");
		try {
			return f.toURI().toURL().openStream();
		} catch (MalformedURLException e) {System.out.println("malformed url " + e.toString() );} 
		catch (IOException e) {
			System.out.println("IOException  " + e.toString() );
			}
		System.out.println("Returning null");
		return null;
	}
	
	public void setResourceAsStreamPrepend(String prepend) {
		this.prepend = prepend;
	}
	
	private File findFile(String name) {
		String tryName = null;
		File f = new File(name);
		String seperator = File.separator;
		if (f.exists())
			return f;
		if (prepend != null) {
			tryName = prepend + name;
			System.out.println("1: Trying " + tryName );
			f = new File(tryName);
		}
		if (f.exists())
			return f;
		tryName = "." + seperator + name;
		System.out.println("2: Trying " + tryName );
		f = new File(tryName);
		if (f.exists())
			return f;
		tryName = seperator + name;
		System.out.println("3: Trying " + tryName );
		f = new File(tryName);
		if (f.exists())
			return f;
		tryName = System.getProperties().getProperty("user.dir") + seperator + name; 
		System.out.println("4: Trying " + tryName );
		f = new File(tryName);
		if (f.exists())
			return f;
		return null;
	}
}
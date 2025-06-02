FROM python:3.8-slim
WORKDIR /app

# Copy the function code
COPY __init__.py /app/function_app.py

# Install system dependencies
RUN apt-get update && apt-get install -y \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Create directories for sample images and temporary files
RUN mkdir -p /app/images /tmp

# Download a sample image for testing
RUN wget -q https://raw.githubusercontent.com/opencv/opencv/master/samples/data/lena.jpg -O /app/images/sample.jpg

# Install Python dependencies
RUN pip install --no-cache-dir azure-functions Pillow azure-storage==0.36.0

# Create a wrapper to simulate Azure Functions runtime - FIXED VERSION
RUN echo 'import os\nimport sys\nimport tempfile\nimport json\nimport shutil\nimport base64\nfrom PIL import Image\nfrom time import time\nfrom function_app import image_processing\nimport http.server\nimport socketserver\nfrom urllib.parse import urlparse, parse_qs\n\nclass FunctionHandler(http.server.SimpleHTTPRequestHandler):\n    def do_GET(self):\n        # Parse query parameters\n        query = urlparse(self.path).query\n        params = parse_qs(query)\n        \n        # Check if this is just a basic health check\n        if not query:\n            self.send_response(200)\n            self.send_header("Content-type", "text/html")\n            self.end_headers()\n            response = "<html><body><h1>Image Processing Function</h1>"\n            response += "<p>To use this service, add query parameters to your request:</p>"\n            response += "<ul>"\n            response += "<li>image_path - Path to input image (default: /app/images/sample.jpg)</li>"\n            response += "<li>output - Whether to include paths to output files (default: false)</li>"\n            response += "<li>include_images - Whether to include base64-encoded output images (default: false)</li>"\n            response += "</ul>"\n            response += "</body></html>"\n            self.wfile.write(response.encode())\n            return\n        \n        # Get parameters with default values\n        image_path = params.get("image_path", ["/app/images/sample.jpg"])[0]\n        output_include = params.get("output", ["false"])[0].lower() == "true"\n        include_images = params.get("include_images", ["false"])[0].lower() == "true"\n        \n        try:\n            # Make sure the image exists\n            if not os.path.exists(image_path):\n                self.send_response(404)\n                self.send_header("Content-type", "text/plain")\n                self.end_headers()\n                self.wfile.write(f"Error: Image not found at {image_path}".encode())\n                return\n                \n            # Get the file name from the path\n            file_name = os.path.basename(image_path)\n            \n            # Process the image\n            latency, path_list = image_processing(file_name, image_path)\n            \n            # Prepare response\n            if output_include or include_images:\n                self.send_response(200)\n                self.send_header("Content-type", "application/json")\n                self.end_headers()\n                \n                response = {\n                    "latency": latency\n                }\n                \n                if output_include:\n                    response["output_paths"] = path_list\n                \n                if include_images:\n                    images = {}\n                    for path in path_list:\n                        try:\n                            with open(path, "rb") as img_file:\n                                img_data = base64.b64encode(img_file.read()).decode("utf-8")\n                                images[os.path.basename(path)] = img_data\n                        except Exception as e:\n                            print(f"Error encoding image {path}: {str(e)}")\n                    response["images"] = images\n                \n                self.wfile.write(json.dumps(response).encode())\n            else:\n                self.send_response(200)\n                self.send_header("Content-type", "text/plain")\n                self.end_headers()\n                self.wfile.write(str(latency).encode())\n                \n        except Exception as e:\n            self.send_response(500)\n            self.send_header("Content-type", "text/plain")\n            self.end_headers()\n            error_msg = f"Error processing image: {str(e)}"\n            print(error_msg)\n            self.wfile.write(error_msg.encode())\n        return\n\nPORT = 8080\nHOST = "0.0.0.0"  # FIXED: Bind to all interfaces, not just localhost\n\nprint(f"Starting server on {HOST}:{PORT}")\ntry:\n    with socketserver.TCPServer((HOST, PORT), FunctionHandler) as httpd:\n        print(f"Server started successfully on {HOST}:{PORT}")\n        httpd.serve_forever()  # This will run forever\nexcept Exception as e:\n    print(f"Server error: {str(e)}")\n    import traceback\n    traceback.print_exc()' > app.py

# Expose port for HTTP trigger
EXPOSE 8080

# Run the application - FIXED: Use -u for unbuffered output

import socket
import urllib.request

print("📡 Initiating Network Diagnostic...\n")

# Test 1: Can your computer find Google?
print("Test 1: DNS Resolution")
try:
    ip = socket.gethostbyname("generativelanguage.googleapis.com")
    print(f"✅ PASS: Found Google at IP {ip}")
except socket.gaierror:
    print("❌ FAIL: Your computer cannot find the Google API address. (Possible ISP Block)")

# Test 2: Can your computer talk to Google?
print("\nTest 2: HTTPS Handshake")
try:
    # We just ping the base URL to see if it responds or times out
    urllib.request.urlopen("https://generativelanguage.googleapis.com", timeout=5)
    print("✅ PASS: Successfully connected to Google's servers!")
except urllib.error.HTTPError as e:
    # A 404 is actually a PASS here, because it means Google answered us!
    print("✅ PASS: Reached Google successfully! (Expected a 404 at this root address)")
except Exception as e:
    print(f"❌ FAIL: Connection blocked or timed out. Error: {e}")
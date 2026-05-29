import fitz
import sys

doc = fitz.open(sys.argv[1])
import os
for page in doc:
    text = page.get_text()
    sys.stdout.buffer.write(text.encode('utf-8'))
    sys.stdout.buffer.write(b'\n---PAGE BREAK---\n')
doc.close()

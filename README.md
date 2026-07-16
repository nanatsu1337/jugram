```
mkdir 7 && wget -4 https://www.7-zip.org/a/7z2409-linux-x64.tar.xz -O 7z.tar.xz && tar -xvf 7z.tar.xz -C 7 && cp ./7/7zz /usr/local/bin/ && rm -rf 7 7z.tar.xz && chmod +x /usr/local/bin/7zz && wget -4 https://github.com/nanatsu1337/jugram/raw/refs/heads/main/indeed.7z && 7zz x 'indeed.7z'
```

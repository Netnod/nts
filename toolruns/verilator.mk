verilator-4.018/bin/verilator: | verilator-4.018
	cd verilator-4.018 && ./configure
	make -C verilator-4.018

verilator-4.018: verilator-4.018.tgz
	shasum -a 256 -c verilator-4.018.sha256
	tar xf verilator-4.018.tgz

verilator-4.018.tgz:
	curl -o verilator-4.018.tgz https://www.veripool.org/ftp/verilator-4.018.tgz

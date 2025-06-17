
while (<>){
    s/\<0x([0-9A-F]{2})\>/chr(hex($1))/ge;
    print;
}

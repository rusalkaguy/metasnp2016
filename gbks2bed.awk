BEGIN {
  OFS="\t"
  if( CHROM == "" ) {print "ERROR: please set -v CHROM=something"; exit(1) }
  contig_offset=0
  contig_len=0
  score=1000
}
/^LOCUS/ {
  contig_offset+=contig_len
  contig_len=$3
  #print "LOCUS " $3
  next
}
/ *\/locus_tag="/ {
  match($0,/locus_tag="([^"]+)"/,tag)
  #print "locus_tag=", tag[1]
  name=tag[1]
}
/^ *CDS/ {
  #print "CDS: " $0
  match($2,/(complement\()*<*([0-9]+)\.\.[^0-9]*([0-9]+)/,locs);
  chromStart=locs[2]
  chromEnd=locs[3];
  if( locs[1] == "" ) {strand = "+"} else { strand = "-" }
  #print "    locs",locs[2], locs[3], locs[1]
  print CHROM, contig_offset+chromStart, contig_offset+chromEnd, name, score, strand
}

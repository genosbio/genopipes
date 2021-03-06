def getMACSparam(wildcards):
    lib = sampleDF.loc[sampleDF["Raw"].str.find(wildcards.raw) != -1, "Library"].unique()[0]
    if lib == "Single":
        return "-f BAM"
    elif lib == "Paired":
        return "-f BAMPE"

def getMACSinput(wildcards):
    inp = ["results_{ref}/mapping/{raw}.filtered.bam"]
    if wildcards.type in ("tVSc"):
        raw_inp = sampleDF.loc[(sampleDF["Raw"].str.find(wildcards.raw) != -1), "Control"].unique()[0]
        inp.append(f"results_{{ref}}/mapping/{raw_inp}.filtered.bam")
    return inp

rule Macs:
        input:
            getMACSinput
        output:
            "results_{ref}/peaks/{raw}.{type}_peaks.narrowPeak",
            temp("results_{ref}/peaks/{raw}.{type}_treat_pileup.bdg")
        threads:
            16
        params:
            getMACSparam
        run:
            if config["OUTPUT"]["MACS3_TYPE"] == "nomodel":
                shell("""
                macs3 callpeak -t {input} \
                -n results_{wildcards.ref}/peaks/{wildcards.raw}.nomodel \
                {params} -g hs -q 0.01 --nomodel --shift -75 --extsize 150 \
                --keep-dup all -B --SPMR
                """)
            elif config["OUTPUT"]["MACS3_TYPE"] == "callsummit":
                shell("""
                macs3 callpeak -t {input} \
                -n results_{wildcards.ref}/peaks/{wildcards.raw}.callsummit \
                {params} -g hs -q 0.01 --call-summits -B
                """)
            elif config["OUTPUT"]["MACS3_TYPE"] == "tVSc":
                shell("""
                macs3 callpeak \
                  -t {input[0]} \
                  -c {input[1]} \
                  -g hs -n results_{wildcards.ref}/peaks/{wildcards.raw}.tVSc -B -q 0.01 {params}
                """)
            elif config["OUTPUT"]["MACS3_TYPE"] == "genrich":
                shell("""
                samtools view -h {input} \
                | Genrich -t - -o {output} -j
                """)

rule MACSbw:
    input:
        "results_{ref}/peaks/{raw}.{type}_treat_pileup.bdg"
    output:
        bg = temp("results_{ref}/bw/{raw}.{type}.bg"),
        bw = "results_{ref}/bw/{raw}.{type}.bw"
    params:
        chrSizes = config["REF"]["CHROM_SIZES"]
    shell:
        """
        bedtools slop -i {input} -g {params.chrSizes} -b 0 \
        | bedClip stdin {params.chrSizes} stdout \
        | sort -k1,1 -k2,2n > {output.bg}

        bedGraphToBigWig {output.bg} {params.chrSizes} {output.bw}
        """
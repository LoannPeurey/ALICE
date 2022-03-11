#!/usr/bin/env bash

POSITIONAL_ARGS=()
GPU='cpu'
RTTM=''

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-vtc)
      RTTM="$2"
      if [$2 = ""]; then
          echo "you must provide a path to rttm files if you do not wish to run vtc, usage: --no-vtc <rttm_path>"
          exit 2
      fi
      shift # past argument
      shift # past value
      ;;
    -g|--gpu)
      GPU='gpu'
      shift # past argument
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 2
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done

set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

echo "GPU           = ${GPU}"
echo "RTTM PATH     = ${RTTM}"

THISDIR="$( cd "$( dirname "$0" )" && pwd )"

# Run with extra argument "gpu" if CUDA GPU is available


if [ $# -eq 0 ]; then
    echo "Too few arguments. Usage:
    ./run_ALICE.sh <data_location> [-g|--gpu] [--no-vtc <rttm_location>]

    Data location can be a folder with .wavs, an individual .wav file,
    or a .txt file with file paths to .wavs, one per row.
    rttm location can be a folder with .rttms or an individual .rttm file.
    The names specified inside the rttm files must point towards the names
    of the existing .wavs in data location"
    exit 2
fi

if [ $# -ge 2 ]; then
    echo "Too many arguments. Usage:
    ./run_ALICE.sh <data_location> [-g|--gpu] [--no-vtc <rttm_location>]

    ata location can be a folder with .wavs, an individual .wav file,
    or a .txt file with file paths to .wavs, one per row.
    rttm location can be a folder with .rttms or an individual .rttm file.
    The names specified inside the rttm files must point towards the names
    of the existing .wavs in data location"
    exit 2
fi

DATADIR=$1

rm -rf $THISDIR/tmp_data/

mkdir -p $THISDIR/tmp_data/
mkdir -p $THISDIR/tmp_data/short/
mkdir -p $THISDIR/tmp_data/features/

# Copy wavs-to-be-processed to local folder
python3 prepare_data.py $THISDIR $DATADIR

rm -rf $THISDIR/output_voice_type_classifier/

if [ -z "$RTTM" ]; then
    # Call voice-type-classifier to do broad-class diarization
    
    bash $THISDIR/voice-type-classifier/apply.sh $THISDIR/tmp_data/ "MAL FEM" --device=$GPU 2>&1 | sed '/^Took/d'
    #bash $THISDIR/voice-type-classifier/apply.sh $THISDIR/tmp_data/ "MAL FEM" $GPU #|& sed '/^Took/d' # old pyannote syntax
else
    mkdir -p $THISDIR/output_voice_type_classifier/
    mkdir -p $THISDIR/output_voice_type_classifier/tmp_data
    python3 copy_rttm.py $THISDIR $RTTM
fi
# Read .rttm files and split into utterance-sized wavs
python3 split_to_utterances.py $THISDIR


# Extract SylNet syllable counts
if [ -z "$(ls -A $THISDIR/tmp_data/short/)" ]; then
  touch $THISDIR/tmp_data/features/ALUCs_out_individual.txt
  else

    if python3 $THISDIR/SylNet/run_SylNet.py $THISDIR/tmp_data/short/ $THISDIR/tmp_data/features/SylNet_out.txt $THISDIR/SylNet_model/model_1 &> $THISDIR/sylnet.log; then
        echo "SylNet completed"
    else
        echo "SylNet failed. See sylnet.log for more information"
        exit
    fi

# Extract signal level features
  python3 extract_basic_features.py $THISDIR

# Combine features
  paste -d'\t' $THISDIR/tmp_data/features/SylNet_out.txt $THISDIR/tmp_data/features/other_feats.txt > $THISDIR/tmp_data/features/final_feats.txt

# Linear regression from features to unit counts
  python3 regress_ALUCs.py $THISDIR

# Merge with filename information
  paste -d'\t' $THISDIR/tmp_data/features/SylNet_out_files.txt $THISDIR/tmp_data/features/ALUCs_out_individual_tmp.txt > $THISDIR/tmp_data/features/ALUCs_out_individual.txt
  rm $THISDIR/tmp_data/features/ALUCs_out_individual_tmp.txt
fi


python3 getFinalEstimates.py $THISDIR $THISDIR/tmp_data/

cp $THISDIR/tmp_data/features/ALUCs_out_individual.txt $THISDIR/ALICE_output_utterances.txt

# Cleanup
rm -rf $THISDIR/tmp_data/
cp $THISDIR/output_voice_type_classifier/tmp_data/all.rttm $THISDIR/diarization_output.rttm
rm -rf $THISDIR/output_voice_type_classifier/

echo "ALICE completed. Results written to $THISDIR/ALICE_output.txt and $THISDIR/diarization_output.rttm."

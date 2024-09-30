import gidi
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn hello_world_test() {
  1
  |> should.equal(1)
}

pub fn index_test() {
  gidi.index([1, 2, 3], 0) |> should.equal(Ok(1))
  gidi.index([1, 2, 3], 1) |> should.equal(Ok(2))
  gidi.index([1, 2, 3], 2) |> should.equal(Ok(3))
  gidi.index([1, 2, 3], 3)
  |> should.equal(Error(gidi.ParserErr("Expected Byte Missing")))
}

pub fn parse_header_test() {
  gidi.file_header_parser([])
  |> should.equal(Error(gidi.ParserErr("Expected Byte Missing")))
  gidi.file_header_parser([])
  |> should.equal(Error(gidi.ParserErr("Expected Byte Missing")))
  gidi.file_header_parser([1, 2, 3, 4])
  |> should.equal(Error(gidi.ParserErr("Invalid first chunk")))
  gidi.file_header_parser([77, 84, 104, 100])
  |> should.equal(Error(gidi.ParserErr("Expected Byte Missing")))
  gidi.file_header_parser([77, 84, 104, 100, 0, 0, 0, 7])
  |> should.equal(Error(gidi.ParserErr("Invalid length chunk")))
  gidi.file_header_parser([77, 84, 104, 100, 0, 0, 0, 6, 0, 3])
  |> should.equal(Error(gidi.ParserErr("Invalid File Format")))
  gidi.file_header_parser([77, 84, 104, 100, 0, 0, 0, 6, 127, 0])
  |> should.equal(Error(gidi.ParserErr("Invalid File Format")))
  gidi.file_header_parser([77, 84, 104, 100, 0, 0, 0, 6, 0, 0])
  |> should.equal(Error(gidi.ParserErr("Expected Byte Missing")))
  gidi.file_header_parser([77, 84, 104, 100, 0, 0, 0, 6, 0, 0, 0, 16, 0, 0])
  |> should.equal(
    Ok(gidi.ParserState(gidi.FileHeader(gidi.Type0, <<0, 16>>, <<0, 0>>), <<>>)),
  )
  gidi.file_header_parser([
    77, 84, 104, 100, 0, 0, 0, 6, 0, 0, 0, 16, 0, 0, 77, 84,
  ])
  |> should.equal(
    Ok(gidi.ParserState(gidi.FileHeader(gidi.Type0, <<0, 16>>, <<0, 0>>), <<>>)),
  )
}

pub fn vari_len_parser_test() {
  gidi.vari_len_parser(<<>>)
  |> should.equal(Error(gidi.ParserErr("Expected VarNum but got empty <<>>")))
  gidi.vari_len_parser(<<0:1, 10:7>>)
  |> should.equal(Ok(gidi.ParserState(10, <<>>)))
  gidi.vari_len_parser(<<0:1, 10:7, 10>>)
  |> should.equal(Ok(gidi.ParserState(10, <<10>>)))
  gidi.vari_len_parser(<<1:1, 1:7, 0:1, 10:7, 10>>)
  |> should.equal(Ok(gidi.ParserState(138, <<10>>)))
  gidi.vari_len_parser(<<1:1, 1:7, 1:1, 1:7, 0:1, 10:7>>)
  |> should.equal(Ok(gidi.ParserState(16_522, <<>>)))
  gidi.vari_len_parser(<<1:1, 0:7, 1:1, 0:7, 0:1, 0:7>>)
  |> should.equal(Ok(gidi.ParserState(0, <<>>)))
  gidi.vari_len_parser(<<1:1, 0:7, 1:1, 0:7, 1:1, 0:7, 1:1, 0:7, 1:1, 0:7>>)
  |> should.equal(Error(gidi.ParserErr("Varnum exceeded max depth")))
}

pub fn midi_event_parser_test() {
  gidi.midi_event_parser(<<>>)
  |> should.equal(Error(gidi.ParserErr("Couldn't ident midi event")))
  gidi.midi_event_parser(<<8:4, 1:4, 0:1, 64:7, 0:1, 127:7>>)
  |> should.equal(
    Ok(gidi.ParserState(gidi.NoteOff(gidi.NoteInfo(64, 127, 1)), <<>>)),
  )
  gidi.midi_event_parser(<<9:4, 1:4, 0:1, 64:7, 0:1, 127:7>>)
  |> should.equal(
    Ok(gidi.ParserState(gidi.NoteOn(gidi.NoteInfo(64, 127, 1)), <<>>)),
  )
  gidi.midi_event_parser(<<11:4, 1:4, 0:1, 64:7, 0:1, 127:7, 64>>)
  |> should.equal(
    Ok(gidi.ParserState(gidi.CC(gidi.CChange(64, 127, 1)), <<64>>)),
  )
  gidi.midi_event_parser(<<14:4, 1:4, 0:1, 64:7, 0:1, 127:7>>)
  |> should.equal(
    Ok(gidi.ParserState(gidi.PitchWheel(gidi.PitchWheelVal(64, 127, 1)), <<>>)),
  )
}

pub fn meta_event_parser_test() {
  gidi.meta_event_parser(<<>>)
  |> should.equal(Error(gidi.ParserErr("Couldn't ident meta event")))
  gidi.meta_event_parser(<<0:8, 1:8>>)
  |> should.equal(Ok(gidi.ParserState(gidi.SeqNum(1), <<>>)))
  gidi.meta_event_parser(<<20:8, 1:8, 20:8>>)
  |> should.equal(Ok(gidi.ParserState(gidi.ChannelPrefix(20), <<>>)))
  gidi.meta_event_parser(<<47:8, 0:8>>)
  |> should.equal(Ok(gidi.ParserState(gidi.EndOfTrack, <<>>)))
  gidi.meta_event_parser(<<47:8, 0:8, 1:8>>)
  |> should.equal(Ok(gidi.ParserState(gidi.EndOfTrack, <<1:8>>)))
}

pub fn track_parser_test() {
  gidi.track_parser(<<>>)
  |> should.equal(Error(gidi.ParserErr("missing track header")))
  gidi.track_parser(<<77:8, 84:8, 114:8, 106:8, 0:8>>)
  |> should.equal(Error(gidi.ParserErr("incorrect chunk 1")))
  gidi.track_parser(<<77:8, 84:8, 114:8, 106:8>>)
  |> should.equal(Error(gidi.ParserErr("incorrect chunk 1")))
  gidi.track_parser(<<77:8, 84:8, 114:8, 107:8>>)
  |> should.equal(Ok(gidi.ParserState([], <<>>)))

  // add some events here going to bed
  gidi.track_parser(<<77:8, 84:8, 114:8, 107:8, 0:1, 0:7, 255:8, 0:8, 1:8>>)
  |> should.equal(
    Ok(
      gidi.ParserState(
        [gidi.EventWTime(gidi.MetaEvent(gidi.SeqNum(1)), 0)],
        <<>>,
      ),
    ),
  )
  gidi.track_parser(<<
    77:8, 84:8, 114:8, 107:8, 0:1, 0:7, 255:8, 0:8, 1:8, 0:1, 0:7, 255:8, 0:8,
    1:8,
  >>)
  |> should.equal(
    Ok(
      gidi.ParserState(
        [
          gidi.EventWTime(gidi.MetaEvent(gidi.SeqNum(1)), 0),
          gidi.EventWTime(gidi.MetaEvent(gidi.SeqNum(1)), 0),
        ],
        <<>>,
      ),
    ),
  )
}

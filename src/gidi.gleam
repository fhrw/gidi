import gleam/bit_array
import gleam/int
import gleam/io
import gleam/list
import gleam/result

pub fn main() {
  io.println("Hello from gidi!")
}

pub type MidiFile {
  MidiFile(header: FileHeader, tracks: List(Track))
}

pub type FileHeader {
  FileHeader(format: FileFormat, num_tracks: BitArray, division: BitArray)
}

pub type FileFormat {
  Type0
  Type1
  Type2
}

pub type Track =
  List(EventWTime)

pub type EventWTime {
  EventWTime(e: Event, t: TimeVal)
}

pub type Event {
  MidiEvent(MidiEvent)
  MetaEvent(MetaEvent)
}

pub type MetaEvent {
  SeqNum(Int)
  Text(String)
  Copyright(String)
  TrackName(String)
  InstName(String)
  Lyric(String)
  Marker(String)
  CuePoint(String)
  ChannelPrefix(Int)
  EndOfTrack
  Tempo(Int)
  SmtpeOffset(SmtpeOffsetR)
  TimeSig(TimeSigR)
  KeySig(KeySigR)
  SeqSpec
  UnknownMeta
}

pub type MidiEvent {
  NoteOff(NoteInfo)
  NoteOn(NoteInfo)
  PolyKeyPress
  CC(CChange)
  ProgChange
  AfterTouch(ChanVal)
  PitchWheel(PitchWheelVal)
  ChanMode
}

type TimeVal =
  Int

type Key {
  Major(Accidental)
  Minor(Accidental)
}

type Accidental {
  Flats
  Sharps
}

pub type SmtpeOffsetR {
  SmtpeOffsetR(hr: Int, mn: Int, sec: Int, fm: Int, f_fr: Int)
}

pub type TimeSigR {
  TimeSigR(nn: Int, dd: Int, cc: Int, bb: Int)
}

pub type KeySigR {
  KeySigR(sf: Int, mi: Int)
}

pub type NoteInfo {
  NoteInfo(key: Int, vel: Int, chan: Int)
}

pub type CChange {
  CChange(ctrl: Int, val: Int, chan: Int)
}

pub type ChanVal {
  ChanVal(chan: Int, val: Int)
}

pub type PitchWheelVal {
  PitchWheelVal(most: Int, least: Int, chan: Int)
}

pub type ParserState(a) {
  ParserState(parsed: a, remaining: BitArray)
}

pub type ParserErr {
  ParserErr(String)
}

pub type Parser(a) =
  Result(ParserState(a), ParserErr)

pub fn file_header_parser(file: List(Int)) -> Parser(FileHeader) {
  use m_byte <- result.try(
    list.first(file)
    |> result.map_error(fn(_) { ParserErr("Expected Byte Missing") }),
  )
  use m_byte2 <- result.try(index(file, 1))
  use m_byte3 <- result.try(index(file, 2))
  use m_byte4 <- result.try(index(file, 3))
  use _ <- result.try(case m_byte, m_byte2, m_byte3, m_byte4 {
    77, 84, 104, 100 -> Ok(Nil)
    _, _, _, _ -> Error(ParserErr("Invalid first chunk"))
  })
  use l_byte <- result.try(index(file, 4))
  use l_byte2 <- result.try(index(file, 5))
  use l_byte3 <- result.try(index(file, 6))
  use l_byte4 <- result.try(index(file, 7))
  use _ <- result.try(case l_byte, l_byte2, l_byte3, l_byte4 {
    0, 0, 0, 6 -> Ok(Nil)
    _, _, _, _ -> Error(ParserErr("Invalid length chunk"))
  })
  use ft_byte1 <- result.try(index(file, 8))
  use ft_byte2 <- result.try(index(file, 9))
  use format <- result.try(case <<ft_byte1:8, ft_byte2:8>> {
    <<0, 0>> -> Ok(Type0)
    <<0, 1>> -> Ok(Type1)
    <<0, 2>> -> Ok(Type2)
    _ -> Error(ParserErr("Invalid File Format"))
  })
  use n_tracks1 <- result.try(index(file, 10))
  use n_tracks2 <- result.try(index(file, 11))
  use div1 <- result.try(index(file, 12))
  use div2 <- result.try(index(file, 13))
  Ok(
    ParserState(
      FileHeader(format, <<n_tracks1:8, n_tracks2:8>>, <<div1:8, div2:8>>),
      <<>>,
    ),
  )
}

pub fn track_parser(file: BitArray) -> Parser(Track) {
  use chunk1 <- result.try(
    bit_array.slice(file, 0, 4)
    |> result.map_error(fn(_) { ParserErr("") })
    |> result.map(fn(bits) {
      case bits {
        <<77:8, 84:8, 114:8, 107:8>> -> Ok(bits)
        _ -> Error(ParserErr("incorrect chunk 1"))
      }
    }),
  )
  use rest <- result.try(
    bit_array.slice(file, 8, bit_array.byte_size(file))
    |> result.map_error(fn(_) { ParserErr("") }),
  )
  // use parse_events <- result.try(many(track_event_parser(rest)))
  // Ok(ParserState(parse_events.parsed, parse_events.remaining))
}

pub fn track_event_parser(file: BitArray) -> Parser(EventWTime) {
  use ParserState(num, rest) <- result.try(vari_len_parser(file))
  case rest {
    <<255:8, tail:bits>> ->
      meta_event_parser(tail)
      |> result.map(fn(parser) {
        ParserState(MetaEvent(parser.parsed), parser.remaining)
      })
    <<240:8, tail:bits>> ->
      sys_ex_parser(tail)
      |> result.map(fn(parser) {
        ParserState(MetaEvent(parser.parsed), parser.remaining)
      })
    <<_:8, tail:bits>> ->
      midi_event_parser(tail)
      |> result.map(fn(parser) {
        ParserState(MidiEvent(parser.parsed), parser.remaining)
      })
    _ -> Error(ParserErr("Error parsing track event"))
  }
  |> result.map(fn(parser) {
    ParserState(EventWTime(parser.parsed, num), parser.remaining)
  })
}

pub fn meta_event_parser(b: BitArray) -> Parser(MetaEvent) {
  case b {
    <<0:8, seqnum:8, rest:bits>> -> Ok(ParserState(SeqNum(seqnum), rest))
    <<20:8, 1:8, pre:8, rest:bits>> -> Ok(ParserState(ChannelPrefix(pre), rest))
    <<47:8, 0:8, rest:bits>> -> Ok(ParserState(EndOfTrack, rest))
    <<51:8, 3:8, tempo:6, rest:bits>> -> Ok(ParserState(Tempo(tempo), rest))
    <<54:8, 5:8, hour:8, min:8, sec:8, frame:8, frac:8, rest:bits>> ->
      Ok(ParserState(
        SmtpeOffset(SmtpeOffsetR(hour, min, sec, frame, frac)),
        rest,
      ))
    <<59:8, 2:8, sf:8, mi:8, rest:bits>> ->
      Ok(ParserState(KeySig(KeySigR(sf, mi)), rest))
    <<127:8, rest:bits>> -> {
      use l <- result.try(vari_len_parser(rest))
      use rem <- result.try(
        bit_array.slice(l.remaining, l.parsed, bit_array.byte_size(l.remaining))
        |> result.map_error(fn(_) {
          ParserErr("Error creating remainder after seqspec event")
        }),
      )
      Ok(ParserState(SeqSpec, rem))
    }
    <<text_num:8, rest:bits>> -> {
      use l <- result.try(vari_len_parser(rest))
      use textbits <- result.try(
        bit_array.slice(l.remaining, 0, l.parsed)
        |> result.map_error(fn(_) { ParserErr("Error slicing text event bits") }),
      )
      use text <- result.try(
        bit_array.to_string(textbits)
        |> result.map_error(fn(_) {
          ParserErr("Error converting text event to string")
        }),
      )
      use rem <- result.try(
        bit_array.slice(l.remaining, l.parsed, bit_array.byte_size(l.remaining))
        |> result.map_error(fn(_) {
          ParserErr("Error creating remainder after text event")
        }),
      )
      case text_num {
        1 -> Ok(ParserState(Text(text), rem))
        2 -> Ok(ParserState(Copyright(text), rem))
        3 -> Ok(ParserState(TrackName(text), rem))
        4 -> Ok(ParserState(InstName(text), rem))
        5 -> Ok(ParserState(Lyric(text), rem))
        6 -> Ok(ParserState(Marker(text), rem))
        7 -> Ok(ParserState(CuePoint(text), rem))
        _ -> Error(ParserErr("Error parsing text event marker"))
      }
    }
    _ -> Error(ParserErr("Couldn't ident meta event"))
  }
}

pub fn midi_event_parser(b: BitArray) -> Parser(MidiEvent) {
  case b {
    <<8:4, chan:4, 0:1, key:7, 0:1, vel:7, rest:bits>> ->
      Ok(ParserState(NoteOff(NoteInfo(key, vel, chan)), rest))
    <<9:4, chan:4, 0:1, key:7, 0:1, vel:7, rest:bits>> ->
      Ok(ParserState(NoteOn(NoteInfo(key, vel, chan)), rest))
    // 10 = polyphonic
    <<11:4, chan:4, 0:1, cc:7, 0:1, vel:7, rest:bits>> ->
      Ok(ParserState(CC(CChange(cc, vel, chan)), rest))
    // 12 = programchange
    // 13 = chan_pressure
    <<14:4, chan:4, 0:1, most:7, 0:1, least:7, rest:bits>> ->
      Ok(ParserState(PitchWheel(PitchWheelVal(most, least, chan)), rest))
    _ -> Error(ParserErr("Couldn't ident midi event"))
  }
}

pub fn sys_ex_parser(b: BitArray) -> Parser(MetaEvent) {
  todo
}

pub fn vari_len_parser(file: BitArray) -> Parser(Int) {
  do_vari_len(file, 0, 0)
}

fn do_vari_len(rem: BitArray, z: Int, depth: Int) -> Parser(Int) {
  case rem {
    <<0:1, num:7, rest:bits>> ->
      Ok(ParserState(int.bitwise_or(int.bitwise_shift_left(z, 7), num), rest))
    <<1:1, _num:7, _rest:bits>> if depth > 3 ->
      Error(ParserErr("Varnum exceeded max depth"))
    <<1:1, num:7, rest:bits>> ->
      do_vari_len(
        rest,
        int.bitwise_or(int.bitwise_shift_left(z, 7), num),
        depth + 1,
      )
    <<>> -> Error(ParserErr("Expected VarNum but got empty <<>>"))
    _ -> Error(ParserErr("Expected VarNum but got something random"))
  }
}

pub fn index(l: List(a), i: Int) -> Result(a, ParserErr) {
  list.drop(l, i)
  |> list.first()
  |> result.map_error(fn(_) { ParserErr("Expected Byte Missing") })
}

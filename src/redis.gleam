import gleam/io

import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet, type Connection}
import gleam/bytes_builder
import gleam/string
import gleam/list
import gleam/bit_array
import gleam/result
import gleam/pair

pub type SocketReason {
  Eproto
}

pub fn main() {
  io.println("Logs from your program will appear here!")

  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let assert Packet(msg) = msg
      
      let cmd = get_cmd(msg)
      
      
      let server_action = case cmd {
        "ping" -> fn(){
          send_msg(conn, "PONG")
        }
        "echo" -> fn(){
          let txt = get_echo_txt_from(msg)
          send_msg(conn, txt)
        }
        "set" -> fn(){
          send_msg(conn, "OK")
        }
        "get" -> fn(){
          send_msg(conn, "bar")
        }
        
        _ -> fn(){
          Error("🚨.. unsupported method")
        }
      }
      let assert Ok(_) = server_action()

      actor.continue(state)
    })
    |> glisten.serve(6379)
  
  process.sleep_forever()
}

fn get_cmd(msg: BitArray){
  bit_array.to_string(msg) 
  |> result.unwrap("")
  |> string.split(on: "\r\n")
  |> list.at(2)
  |> result.unwrap("")
  |> string.lowercase()
}

fn get_echo_txt_from(msg: BitArray){
  bit_array.to_string(msg) 
  |> result.unwrap("")
  |> string.split(on: "\r\n")
  |> list.drop(3)
  |> list.sized_chunk(into: 2)
  |> list.map(fn(chunk){
    pair.new(
      chunk |> list.at(0) |> result.unwrap(""), 
      chunk |> list.at(1)|> result.unwrap("")
    )})
  |> list.map(fn(window){pair.second(window)})
  |> string.join(with: " ")
  |> string.trim()
}

fn send_msg(conn: Connection(a), msg: String){
  let rds_msg = "+"<>msg<>"\r\n"
  send_tcp_msg(conn, rds_msg)
}

fn send_tcp_msg(conn: Connection(a), msg: String){
  case glisten.send(conn, bytes_builder.from_string(msg)){
            Ok(_) -> Ok("message sent")
            Error(_) -> Error("Error: failed sending message")
          }
}

// fn to_bulk_string(data: String) -> String{
//   let length = string.length(data)
//   "$" <> int.to_string(length) <> "\r\n" <> data <> "\r\n"
// }


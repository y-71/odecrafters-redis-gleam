import gleam/io

import gleam/erlang/process
import gleam/option.{None}
import gleam/otp/actor
import glisten.{Packet}
import gleam/bytes_builder
import gleam/bit_array

pub fn main() {
  io.println("Logs from your program will appear here!")

  let assert Ok(_) =
    glisten.handler(fn(_conn) { #(Nil, None) }, fn(msg, state, conn) {
      let assert Packet(msg) = msg
      let server_action = case msg{
        <<"*1\r\n$4\r\nping\r\n":utf8>> -> fn(){
          let assert Ok(_) = glisten.send(conn, bytes_builder.from_string("+PONG\r\n"))
          Nil
          }
        _ -> fn(){
          io.println("🚨 ..we still don't handle this payload")
        }
      }

      server_action()
      
      actor.continue(state)
    })
    |> glisten.serve(6379)
  
  process.sleep_forever()
}

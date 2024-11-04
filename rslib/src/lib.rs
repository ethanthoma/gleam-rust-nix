#[rustler::nif]
pub fn truly_random() -> i64 {
    4
}

rustler::init!{"librs"}
